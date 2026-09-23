<?php

namespace App\Service;

use App\Entity\User;
use App\Repository\DeviceTokenRepository;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
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

        $message = CloudMessage::new()
            ->withNotification(Notification::create($title, $body))
            ->withData($data);

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
        } catch (\Throwable $e) {
            $this->logger->warning('Push notification failed.', ['exception' => $e]);
        }
    }

    private function messaging(): ?Messaging
    {
        if ($this->triedInit) {
            return $this->messaging;
        }

        $this->triedInit = true;

        if ('' === trim($this->firebaseCredentials)) {
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
