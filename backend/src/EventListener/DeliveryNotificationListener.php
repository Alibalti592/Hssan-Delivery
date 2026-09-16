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
 * order is on its way, delivered, cancelled, or failed — the transitions
 * that actually change what the client should expect next. Accept/pickup/
 * decline aren't worth a push: they're courier-internal steps the client
 * has no action to take on.
 *
 * CANCELLED/FAILED fire this regardless of who triggered them (the client's
 * own self-cancel included) — the event carries no actor, and a redundant
 * confirmation push after a self-cancel is harmless, unlike silently
 * leaving a client unnotified when an admin cancels their order instead
 * (see DeliveryService::cancelDeliveryAsAdmin).
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
            DeliveryStatus::CANCELLED => $this->notifyClient(
                $delivery,
                'Commande annulée',
                'Votre commande a été annulée.'
            ),
            DeliveryStatus::FAILED => $this->notifyClient(
                $delivery,
                'Échec de la livraison',
                'La livraison de votre commande a échoué.'
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
