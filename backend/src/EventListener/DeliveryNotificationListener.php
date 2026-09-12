<?php

namespace App\EventListener;

use App\Entity\Delivery;
use App\Enum\DeliveryStatus;
use App\Event\DeliveryStatusChangedEvent;
use App\Service\PushNotificationService;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;

/**
 * Turns delivery status changes into push notifications. A courier is
 * notified when a delivery lands on them; a client is notified once their
 * order is actually on its way and once it's delivered. Every other
 * transition (accept, pickup, decline, cancel, fail) isn't worth a push —
 * pickup/accept are courier-internal and the client already knows they
 * placed an order.
 */
#[AsEventListener(event: DeliveryStatusChangedEvent::class)]
final class DeliveryNotificationListener
{
    public function __construct(
        private readonly PushNotificationService $pushNotificationService,
    ) {
    }

    public function __invoke(DeliveryStatusChangedEvent $event): void
    {
        $delivery = $event->delivery;

        match ($delivery->getStatus()) {
            DeliveryStatus::ASSIGNED => $this->notifyAssignedCourier($delivery),
            DeliveryStatus::ON_THE_WAY => $this->notifyClient(
                $delivery,
                'Votre livreur est en route',
                'Votre commande est en route vers vous.'
            ),
            DeliveryStatus::DELIVERED => $this->notifyClient(
                $delivery,
                'Commande livrée',
                'Votre commande a été livrée. Bon appétit !'
            ),
            default => null,
        };
    }

    private function notifyAssignedCourier(Delivery $delivery): void
    {
        $courier = $delivery->getCourier();

        if (null === $courier) {
            return;
        }

        $this->pushNotificationService->notifyUser(
            $courier,
            'Nouvelle course',
            'Une course vous a été assignée.',
            ['deliveryId' => (string) $delivery->getId()]
        );
    }

    private function notifyClient(Delivery $delivery, string $title, string $body): void
    {
        $order = $delivery->getOrder();
        $user = $order?->getUser();

        if (null === $order || null === $user) {
            return;
        }

        $this->pushNotificationService->notifyUser(
            $user,
            $title,
            $body,
            ['orderId' => (string) $order->getId()]
        );
    }
}
