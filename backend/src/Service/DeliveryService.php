<?php

namespace App\Service;

use App\Entity\Delivery;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Event\DeliveryStatusChangedEvent;
use App\Exception\InvalidOperationException;
use App\Repository\DeliveryRepository;
use Doctrine\DBAL\LockMode;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Contracts\EventDispatcher\EventDispatcherInterface;

final class DeliveryService
{
    private const REASSIGNABLE_STATUSES = [
        DeliveryStatus::ASSIGNED,
        DeliveryStatus::ACCEPTED,
        DeliveryStatus::PICKED_UP,
        DeliveryStatus::ON_THE_WAY,
    ];

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly EventDispatcherInterface $eventDispatcher,
        private readonly DeliveryRepository $deliveryRepository,
    ) {
    }

    public function assignCourier(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        return $this->transitionWithLock($delivery, function (Delivery $delivery) use ($courier) {
            if (DeliveryStatus::PENDING !== $delivery->getStatus()) {
                throw new InvalidOperationException('Only pending deliveries can be assigned.');
            }

            $this->assertCourierAvailableForAssignment($courier, $delivery);

            $delivery->setCourier($courier);
            $delivery->setStatus(DeliveryStatus::ASSIGNED);
            $delivery->setAssignedAt(new \DateTimeImmutable());

            $this->syncOrderStatus($delivery);
        });
    }

    /**
     * Admin-only (see DeliveryController::reassign) — hands an already
     * in-progress delivery to a different courier, for when the original one
     * has gone unresponsive. Unlike assignCourier, this works on a delivery
     * that already has a courier and isn't PENDING; unlike
     * cancelDeliveryAsAdmin, it keeps the customer's order alive instead of
     * killing it. Resets to ASSIGNED and clears the accepted/picked-up
     * timestamps: the new courier hasn't accepted or touched the order yet,
     * so their app should walk them through the same accept → pick up → on
     * the way flow as any other assignment, not start them mid-flight on
     * state a different person reached.
     */
    public function reassignCourier(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        return $this->transitionWithLock($delivery, function (Delivery $delivery) use ($courier) {
            if (!in_array($delivery->getStatus(), self::REASSIGNABLE_STATUSES, true)) {
                throw new InvalidOperationException('This delivery cannot be reassigned at its current status.');
            }

            $this->assertCourierAvailableForAssignment($courier, $delivery);

            $delivery->setCourier($courier);
            $delivery->setStatus(DeliveryStatus::ASSIGNED);
            $delivery->setAssignedAt(new \DateTimeImmutable());
            $delivery->setAcceptedAt(null);
            $delivery->setPickedUpAt(null);

            $this->syncOrderStatus($delivery);
        });
    }

    /**
     * Shared by assignCourier and reassignCourier. Locking the courier row
     * (not just the delivery row the caller already locked) closes a race
     * two concurrent assignments to the *same* courier but *different*
     * deliveries would otherwise have: both could pass the capacity check
     * below before either commits, since neither delivery's row lock
     * protects the other delivery's insert. Serializing on the courier row
     * makes the second request see the first one's delivery once it commits.
     */
    private function assertCourierAvailableForAssignment(
        User $courier,
        Delivery $excludingDelivery,
    ): void {
        if (!in_array('ROLE_LIVREUR', $courier->getRoles(), true)) {
            throw new InvalidOperationException('The selected user is not a courier.');
        }

        if (!$courier->isActive()) {
            throw new InvalidOperationException('This courier has been deactivated.');
        }

        // isAvailable is the courier's own "I'm off duty" toggle (see
        // AuthController::availability) — distinct from admin-controlled
        // isActive, and what the admin map's ONLINE/OFFLINE badge is based
        // on (CourierLocationService::deriveStatus). Without this check an
        // admin could assign a delivery to a courier who just signaled
        // they're unavailable, contradicting what the map shows.
        if (!$courier->isAvailable()) {
            throw new InvalidOperationException('This courier is currently unavailable.');
        }

        $this->entityManager->lock($courier, LockMode::PESSIMISTIC_WRITE);

        $activeDelivery = $this->deliveryRepository->findActiveForCourier($courier);

        // Excluding the delivery being (re)assigned matters for reassignCourier:
        // it's already this courier's "active" delivery when reassigning it
        // back to the same courier, which must not read as "already busy".
        if (null !== $activeDelivery && $activeDelivery->getId() !== $excludingDelivery->getId()) {
            throw new InvalidOperationException('This courier already has an active delivery.');
        }
    }

    public function acceptDelivery(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        return $this->transitionWithLock($delivery, function (Delivery $delivery) use ($courier) {
            if (DeliveryStatus::ASSIGNED !== $delivery->getStatus()) {
                throw new InvalidOperationException('Only assigned deliveries can be accepted.');
            }

            $this->assertAssignedCourier($delivery, $courier);

            $delivery->setStatus(DeliveryStatus::ACCEPTED);
            $delivery->setAcceptedAt(new \DateTimeImmutable());

            $this->syncOrderStatus($delivery);
        });
    }

    public function declineDelivery(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        return $this->transitionWithLock($delivery, function (Delivery $delivery) use ($courier) {
            if (DeliveryStatus::ASSIGNED !== $delivery->getStatus()) {
                throw new InvalidOperationException('Only assigned deliveries can be declined.');
            }

            $this->assertAssignedCourier($delivery, $courier);

            $delivery->setCourier(null);
            $delivery->setStatus(DeliveryStatus::PENDING);
            $delivery->setAssignedAt(null);

            $this->syncOrderStatus($delivery);
        });
    }

    public function markPickedUp(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        return $this->transitionWithLock($delivery, function (Delivery $delivery) use ($courier) {
            if (DeliveryStatus::ACCEPTED !== $delivery->getStatus()) {
                throw new InvalidOperationException('Only accepted deliveries can be marked as picked up.');
            }

            $this->assertAssignedCourier($delivery, $courier);

            $delivery->setStatus(DeliveryStatus::PICKED_UP);
            $delivery->setPickedUpAt(new \DateTimeImmutable());

            $this->syncOrderStatus($delivery);
        });
    }

    public function markOnTheWay(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        return $this->transitionWithLock($delivery, function (Delivery $delivery) use ($courier) {
            if (DeliveryStatus::PICKED_UP !== $delivery->getStatus()) {
                throw new InvalidOperationException('Only picked-up deliveries can be marked as on the way.');
            }

            $this->assertAssignedCourier($delivery, $courier);

            $delivery->setStatus(DeliveryStatus::ON_THE_WAY);

            $this->syncOrderStatus($delivery);
        });
    }

    public function markDelivered(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        return $this->transitionWithLock($delivery, function (Delivery $delivery) use ($courier) {
            if (DeliveryStatus::ON_THE_WAY !== $delivery->getStatus()) {
                throw new InvalidOperationException('Only deliveries that are on the way can be marked as delivered.');
            }

            $this->assertAssignedCourier($delivery, $courier);

            $delivery->setStatus(DeliveryStatus::DELIVERED);
            $delivery->setDeliveredAt(new \DateTimeImmutable());

            $this->syncOrderStatus($delivery);
        });
    }

    /**
     * Client self-service cancel (see OrderService::cancelOrder) — a client
     * can back out while the delivery is still unclaimed or just assigned,
     * but not once a courier has actually accepted it. For an admin's wider
     * recourse on a delivery already in progress, see cancelDeliveryAsAdmin.
     */
    public function cancelDelivery(Delivery $delivery): Delivery
    {
        return $this->transitionWithLock($delivery, function (Delivery $delivery) {
            if (!in_array(
                $delivery->getStatus(),
                [
                    DeliveryStatus::PENDING,
                    DeliveryStatus::ASSIGNED,
                ],
                true
            )) {
                throw new InvalidOperationException('This delivery cannot be cancelled at its current status.');
            }

            $delivery->setStatus(DeliveryStatus::CANCELLED);

            $this->syncOrderStatus($delivery);
        });
    }

    /**
     * Admin-only (see DeliveryController::cancel) — deliberately allowed
     * from any non-terminal status, unlike the client-facing cancelDelivery
     * above. Without this, a delivery a courier can no longer act on (e.g.
     * deactivated mid-flight — see ActiveUserChecker, which locks their
     * account out of every request including markDelivered/failDelivery)
     * had no way to ever leave ACCEPTED/PICKED_UP/ON_THE_WAY: an admin
     * couldn't cancel it either, so the order sat stuck forever. CANCELLED
     * maps to the same OrderStatus::CANCELLED regardless of the prior
     * delivery status (see DeliveryStatus::toOrderStatus), same as
     * failDelivery already does from these statuses — this just gives
     * admins the same exit.
     */
    public function cancelDeliveryAsAdmin(Delivery $delivery): Delivery
    {
        return $this->transitionWithLock($delivery, function (Delivery $delivery) {
            if (in_array(
                $delivery->getStatus(),
                [
                    DeliveryStatus::DELIVERED,
                    DeliveryStatus::CANCELLED,
                    DeliveryStatus::FAILED,
                ],
                true
            )) {
                throw new InvalidOperationException('This delivery cannot be cancelled at its current status.');
            }

            $delivery->setStatus(DeliveryStatus::CANCELLED);

            $this->syncOrderStatus($delivery);
        });
    }

    public function failDelivery(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        return $this->transitionWithLock($delivery, function (Delivery $delivery) use ($courier) {
            if (!in_array(
                $delivery->getStatus(),
                [
                    DeliveryStatus::ACCEPTED,
                    DeliveryStatus::PICKED_UP,
                    DeliveryStatus::ON_THE_WAY,
                ],
                true
            )) {
                throw new InvalidOperationException('This delivery cannot be marked as failed at its current status.');
            }

            $this->assertAssignedCourier($delivery, $courier);

            $delivery->setStatus(DeliveryStatus::FAILED);

            $this->syncOrderStatus($delivery);
        });
    }

    /**
     * Runs a status transition inside a locked transaction so two concurrent
     * requests acting on the same delivery (e.g. two admins assigning it, or
     * a courier double-tapping an action) can't both pass the status check
     * before either one commits. Dispatches DeliveryStatusChangedEvent once
     * the transaction has actually committed — never for one that throws or
     * rolls back — so PushNotificationService only fires on a real change.
     *
     * @param callable(Delivery): void $transition
     */
    private function transitionWithLock(Delivery $delivery, callable $transition): Delivery
    {
        $previousStatus = $delivery->getStatus();

        $delivery = $this->entityManager->wrapInTransaction(function () use ($delivery, $transition) {
            $this->entityManager->lock($delivery, LockMode::PESSIMISTIC_WRITE);
            $this->entityManager->refresh($delivery);

            $transition($delivery);

            $this->entityManager->flush();

            return $delivery;
        });

        if ($delivery->getStatus() !== $previousStatus) {
            $this->eventDispatcher->dispatch(new DeliveryStatusChangedEvent($delivery, $previousStatus));
        }

        return $delivery;
    }

    private function assertAssignedCourier(
        Delivery $delivery,
        User $courier,
    ): void {
        if ($delivery->getCourier()?->getId() !== $courier->getId()) {
            throw new InvalidOperationException('You are not assigned to this delivery.');
        }
    }

    private function syncOrderStatus(Delivery $delivery): void
    {
        $order = $delivery->getOrder();

        if (null === $order) {
            // Data-integrity invariant: every delivery is created with an order.
            // If this is ever null something is broken server-side, not a client error.
            throw new \LogicException('Delivery must be associated with an order.');
        }

        $order->setStatus($delivery->getStatus()->toOrderStatus());
    }
}
