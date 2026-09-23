<?php

namespace App\EventListener;

use App\Entity\Delivery;
use App\Enum\DeliveryStatus;
use App\Event\DeliveryStatusChangedEvent;
use App\Service\PushNotificationService;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;

/**
 * Turns delivery status changes into push notifications. A courier is
 * notified when a delivery lands on them, when it's taken away from them
 * by a reassignment, or when it's cancelled out from under them while
 * they're still working it; a client is notified once their order is on
 * its way, delivered, cancelled, or failed — the transitions that actually
 * change what either side should expect next. Accept/pickup/decline aren't
 * worth a push: they're courier-internal steps the other side has no
 * action to take on.
 *
 * CANCELLED/FAILED fire this regardless of who triggered them (the client's
 * own self-cancel included) — the event carries no actor, and a redundant
 * confirmation push after a self-cancel is harmless, unlike silently
 * leaving a client (or a courier already working the delivery) unnotified
 * when an admin cancels it instead (see DeliveryService::cancelDeliveryAsAdmin).
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
            DeliveryStatus::ASSIGNED => $this->notifyOnAssignment($event),
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
            DeliveryStatus::CANCELLED => $this->notifyOnCancellation($delivery),
            DeliveryStatus::FAILED => $this->notifyClient(
                $delivery,
                'Échec de la livraison',
                'La livraison de votre commande a échoué.'
            ),
            default => null,
        };
    }

    private function notifyOnAssignment(DeliveryStatusChangedEvent $event): void
    {
        $delivery = $event->delivery;
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

        // Distinguishes a reassignment (see DeliveryService::reassignCourier)
        // from a fresh PENDING → ASSIGNED: the previous courier was actively
        // working this delivery and, without this, would only find out it's
        // no longer theirs from a confusing 400 on their next action
        // (assertAssignedCourier rejects them once the courier has changed).
        $previousCourier = $event->previousCourier;

        if (null !== $previousCourier && $previousCourier !== $courier) {
            $this->pushNotificationService->notifyUser(
                $previousCourier,
                'Course réassignée',
                'Cette course a été confiée à un autre livreur.',
                ['deliveryId' => (string) $delivery->getId()]
            );
        }
    }

    private function notifyOnCancellation(Delivery $delivery): void
    {
        $this->notifyClient(
            $delivery,
            'Commande annulée',
            'Votre commande a été annulée.'
        );

        // cancelDeliveryAsAdmin (the only path that reaches CANCELLED with a
        // courier still attached from ACCEPTED/PICKED_UP/ON_THE_WAY, see its
        // own docblock) can pull a delivery out from under a courier already
        // working it — possibly already en route or at the customer's door.
        // Without this they'd have no way to find out except polling.
        $courier = $delivery->getCourier();

        if (null !== $courier) {
            $this->pushNotificationService->notifyUser(
                $courier,
                'Course annulée',
                'Cette course a été annulée.',
                ['deliveryId' => (string) $delivery->getId()]
            );
        }
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
