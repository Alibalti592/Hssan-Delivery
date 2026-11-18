<?php

namespace App\Service;

use App\Entity\User;
use App\Repository\DeviceTokenRepository;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\AndroidConfig;
use Kreait\Firebase\Messaging\ApnsConfig;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Firebase\Messaging\SendReport;
use Psr\Log\LoggerInterface;

/**
 * Sends push notifications via Firebase Cloud Messaging. No-ops when
 * FIREBASE_CREDENTIALS is empty (the default — see .env.example), same as
 * Sentry's SENTRY_DSN: inert until a real project's credentials are
 * supplied, so this never requires a Firebase project for local dev.
 *
 * A failed or skipped push never throws — the delivery/order status change
 * that triggered it must succeed regardless of whether anyone gets notified.
 *
 * Not final: DeliveryNotificationListenerTest mocks this to verify the
 * exact title/body sent for each delivery status, since a real Firebase
 * project is never available in tests to observe the call any other way.
 */
class PushNotificationService
{
    private ?Messaging $messaging = null;
    private bool $triedInit = false;

    public function __construct(
        private readonly DeviceTokenRepository $deviceTokenRepository,
        private readonly string $firebaseCredentials,
        private readonly LoggerInterface $logger,
    ) {
    }

    /**
     * @param array<string, string> $data
     */
    public function notifyUser(User $user, string $title, string $body, array $data = []): void
    {
        $tokens = $this->deviceTokenRepository->findTokenStringsForUser($user);

        if ([] === $tokens) {
            return;
        }

        $messaging = $this->messaging();

        if (null === $messaging) {
            return;
        }

        $message = $this->message($title, $body, $data);

        try {
            $report = $messaging->sendMulticast($message, $tokens);

            // Tokens FCM reports as unknown/invalid are permanently dead
            // (app uninstalled, token rotated, etc.) — without pruning them
            // here they'd sit in device_token forever and get retried on
            // every future notification to this user.
            $staleTokens = [...$report->unknownTokens(), ...$report->invalidTokens()];

            if ([] !== $staleTokens) {
                $this->deviceTokenRepository->deleteByTokens($staleTokens);
            }

            // Firebase refusing a send (wrong project credentials, revoked
            // key, a token from another app...) comes back in the report,
            // not as an exception — without this it would fail in silence.
            if ($report->hasFailures()) {
                $this->logger->warning(sprintf(
                    'Push notification "%s" not delivered to %d of %d device(s) of user #%d: %s',
                    $title,
                    $report->failures()->count(),
                    $report->count(),
                    $user->getId(),
                    implode(' | ', array_unique($report->failures()->map(
                        static fn (SendReport $item): string => $item->error()?->getMessage() ?? 'unknown error'
                    )))
                ));
            }
        } catch (\Throwable $e) {
            $this->logger->warning('Push notification failed.', ['exception' => $e]);
        }
    }

    /** Firebase sends a multicast to at most this many phones at once. */
    private const MULTICAST_LIMIT = 500;

    /**
     * One notification to many phones (a promotion to every customer), in
     * batches Firebase accepts, pruning the dead tokens it reports. Returns
     * how many phones Firebase accepted it for and how many batches failed
     * outright (Firebase down, credentials refused...), or null when push is
     * off on this server (no Firebase credentials): nothing was sent.
     *
     * @param string[]              $tokens
     * @param array<string, string> $data
     *
     * @return array{delivered: int, batches: int, failedBatches: int}|null
     */
    public function broadcast(array $tokens, string $title, string $body, array $data = []): ?array
    {
        $messaging = $this->messaging();

        if (null === $messaging) {
            return null;
        }

        $message = $this->message($title, $body, $data);

        $delivered = 0;
        $failed = 0;
        $batches = array_chunk(array_values(array_unique($tokens)), self::MULTICAST_LIMIT);
        foreach ($batches as $batch) {
            try {
                $report = $messaging->sendMulticast($message, $batch);
                $delivered += $report->successes()->count();

                $stale = [...$report->unknownTokens(), ...$report->invalidTokens()];
                if ([] !== $stale) {
                    $this->deviceTokenRepository->deleteByTokens($stale);
                }
            } catch (\Throwable $e) {
                ++$failed;
                $this->logger->warning('Broadcast push failed for a batch.', ['exception' => $e]);
            }
        }

        return ['delivered' => $delivered, 'batches' => count($batches), 'failedBatches' => $failed];
    }

    /**
     * @param array<string, string> $data
     */
    private function message(string $title, string $body, array $data): CloudMessage
    {
        return CloudMessage::new()
            ->withNotification(Notification::create($title, $body))
            ->withData($data)
            // High priority wakes a phone that's asleep with the app closed
            // to show the notification now, not at its next maintenance
            // window; the app's channel (MainActivity) makes it pop up.
            ->withAndroidConfig(AndroidConfig::new()->withHighMessagePriority())
            // iOS shows a notification silently unless the APNs payload
            // asks for a sound; Android plays its channel's sound.
            ->withApnsConfig(ApnsConfig::new()->withDefaultSound());
    }

    private function messaging(): ?Messaging
    {
        if ($this->triedInit) {
            return $this->messaging;
        }

        $this->triedInit = true;

        if ('' === trim($this->firebaseCredentials)) {
            $this->logger->warning('FIREBASE_CREDENTIALS is empty: push notifications are off.');

            return null;
        }

        try {
            $this->messaging = (new Factory())
                ->withServiceAccount($this->firebaseCredentials)
                ->createMessaging();
        } catch (\Throwable $e) {
            $this->logger->warning('Failed to initialize Firebase Messaging.', ['exception' => $e]);
            $this->messaging = null;
        }

        return $this->messaging;
    }
}
