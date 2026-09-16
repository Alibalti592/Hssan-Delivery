<?php

namespace App\Tests\Unit;

use App\Entity\Delivery;
use App\Entity\Order;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Event\DeliveryStatusChangedEvent;
use App\EventListener\DeliveryNotificationListener;
use App\Service\PushNotificationService;
use PHPUnit\Framework\TestCase;

final class DeliveryNotificationListenerTest extends TestCase
{
    public function testNotifiesTheClientWhenADeliveryIsCancelled(): void
    {
        $client = new User();
        $order = new Order();
        $order->setUser($client);

        $delivery = new Delivery();
        $delivery->setOrder($order);
        $delivery->setStatus(DeliveryStatus::CANCELLED);

        $pushNotificationService = $this->createMock(PushNotificationService::class);
        $pushNotificationService->expects(self::once())
            ->method('notifyUser')
            ->with(
                $client,
                'Commande annulée',
                'Votre commande a été annulée.',
                self::anything()
            );

        $listener = new DeliveryNotificationListener($pushNotificationService);
        $listener(new DeliveryStatusChangedEvent($delivery, DeliveryStatus::ACCEPTED));
    }

    public function testNotifiesTheClientWhenADeliveryFails(): void
    {
        $client = new User();
        $order = new Order();
        $order->setUser($client);

        $delivery = new Delivery();
        $delivery->setOrder($order);
        $delivery->setStatus(DeliveryStatus::FAILED);

        $pushNotificationService = $this->createMock(PushNotificationService::class);
        $pushNotificationService->expects(self::once())
            ->method('notifyUser')
            ->with(
                $client,
                'Échec de la livraison',
                'La livraison de votre commande a échoué.',
                self::anything()
            );

        $listener = new DeliveryNotificationListener($pushNotificationService);
        $listener(new DeliveryStatusChangedEvent($delivery, DeliveryStatus::ON_THE_WAY));
    }

    /**
     * Every other transition (accept, pickup, decline) is courier-internal
     * and must not reach the client at all.
     */
    public function testDoesNotNotifyTheClientOnAnUninterestingTransition(): void
    {
        $client = new User();
        $order = new Order();
        $order->setUser($client);

        $delivery = new Delivery();
        $delivery->setOrder($order);
        $delivery->setStatus(DeliveryStatus::ACCEPTED);

        $pushNotificationService = $this->createMock(PushNotificationService::class);
        $pushNotificationService->expects(self::never())->method('notifyUser');

        $listener = new DeliveryNotificationListener($pushNotificationService);
        $listener(new DeliveryStatusChangedEvent($delivery, DeliveryStatus::ASSIGNED));
    }
}
