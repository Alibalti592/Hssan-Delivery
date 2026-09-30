<?php

namespace App\Tests\Unit;

use App\Entity\User;
use App\Repository\DeviceTokenRepository;
use App\Service\PushNotificationService;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\MessageTarget;
use Kreait\Firebase\Messaging\MulticastSendReport;
use Kreait\Firebase\Messaging\SendReport;
use PHPUnit\Framework\TestCase;
use Psr\Log\AbstractLogger;

/**
 * Firebase refusing a push must leave a trace in the logs — a refusal comes
 * back in the send report, not as an exception.
 */
final class PushNotificationServiceTest extends TestCase
{
    public function testARefusedPushIsLoggedWithFirebasesReason(): void
    {
        $logger = $this->recordingLogger();
        $service = $this->serviceSending(
            MulticastSendReport::withItems([
                SendReport::success(MessageTarget::with(MessageTarget::TOKEN, 'token-a'), ['name' => 'ok']),
                SendReport::failure(
                    MessageTarget::with(MessageTarget::TOKEN, 'token-b'),
                    new \RuntimeException('SenderId mismatch')
                ),
            ]),
            $logger,
            ['token-a', 'token-b'],
        );

        $service->notifyUser($this->user(7), 'Commande annulée', 'Votre commande a été annulée.');

        self::assertSame(
            ['Push notification "Commande annulée" not delivered to 1 of 2 device(s) of user #7: SenderId mismatch'],
            $logger->messages
        );
    }

    public function testADeliveredPushLogsNothing(): void
    {
        $logger = $this->recordingLogger();
        $service = $this->serviceSending(
            MulticastSendReport::withItems([
                SendReport::success(MessageTarget::with(MessageTarget::TOKEN, 'token-a'), ['name' => 'ok']),
            ]),
            $logger,
            ['token-a'],
        );

        $service->notifyUser($this->user(7), 'Commande livrée', 'Bon appétit !');

        self::assertSame([], $logger->messages);
    }

    public function testMissingCredentialsAreReported(): void
    {
        $logger = $this->recordingLogger();
        $tokens = $this->createMock(DeviceTokenRepository::class);
        $tokens->method('findTokenStringsForUser')->willReturn(['token-a']);

        (new PushNotificationService($tokens, '  ', $logger))
            ->notifyUser($this->user(7), 'Commande livrée', 'Bon appétit !');

        self::assertSame(['FIREBASE_CREDENTIALS is empty: push notifications are off.'], $logger->messages);
    }

    /**
     * @param list<string> $tokenStrings
     */
    private function serviceSending(MulticastSendReport $report, AbstractLogger $logger, array $tokenStrings): PushNotificationService
    {
        $tokens = $this->createMock(DeviceTokenRepository::class);
        $tokens->method('findTokenStringsForUser')->willReturn($tokenStrings);

        $messaging = $this->createMock(Messaging::class);
        $messaging->method('sendMulticast')->willReturn($report);

        $service = new PushNotificationService($tokens, '{"fake": "credentials"}', $logger);

        // Skip the real Firebase client: hand the service its Messaging.
        $reflection = new \ReflectionObject($service);
        $reflection->getProperty('messaging')->setValue($service, $messaging);
        $reflection->getProperty('triedInit')->setValue($service, true);

        return $service;
    }

    private function user(int $id): User
    {
        $user = new User();
        (new \ReflectionProperty(User::class, 'id'))->setValue($user, $id);

        return $user;
    }

    private function recordingLogger(): AbstractLogger
    {
        return new class extends AbstractLogger {
            /** @var list<string> */
            public array $messages = [];

            public function log($level, \Stringable|string $message, array $context = []): void
            {
                $this->messages[] = (string) $message;
            }
        };
    }
}
