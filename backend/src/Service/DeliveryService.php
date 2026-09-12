<?php

namespace App\Service;

use App\Entity\Delivery;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Event\DeliveryStatusChangedEvent;
use App\Exception\InvalidOperationException;
use Doctrine\DBAL\LockMode;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Contracts\EventDispatcher\EventDispatcherInterface;

final class DeliveryService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly EventDispatcherInterface $eventDispatcher,
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

            if (!in_array('ROLE_LIVREUR', $courier->getRoles(), true)) {
                throw new InvalidOperationException('The selected user is not a courier.');
            }

            if (!$courier->isActive()) {
                throw new InvalidOperationException('This courier has been deactivated.');
            }

            $delivery->setCourier($courier);
            $delivery->setStatus(DeliveryStatus::ASSIGNED);
            $delivery->setAssignedAt(new \DateTimeImmutable());

            $this->syncOrderStatus($delivery);
        });
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
