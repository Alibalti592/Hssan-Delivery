<?php

namespace App\Service;

use App\Entity\Delivery;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\OrderStatus;
use App\Repository\DeliveryRepository;
use Doctrine\ORM\EntityManagerInterface;

final class DeliveryService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly DeliveryRepository $deliveryRepository,
    ) {
    }

    public function assignCourier(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        if (DeliveryStatus::PENDING !== $delivery->getStatus()) {
            throw new \RuntimeException('Only pending deliveries can be assigned.');
        }

        if (!in_array('ROLE_LIVREUR', $courier->getRoles(), true)) {
            throw new \RuntimeException('The selected user is not a courier.');
        }

        $delivery->setCourier($courier);
        $delivery->setStatus(DeliveryStatus::ASSIGNED);
        $delivery->setAssignedAt(new \DateTimeImmutable());

        $this->syncOrderStatus($delivery);

        $this->entityManager->flush();

        return $delivery;
    }

    public function acceptDelivery(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        if (DeliveryStatus::ASSIGNED !== $delivery->getStatus()) {
            throw new \RuntimeException('Only assigned deliveries can be accepted.');
        }

        $this->assertAssignedCourier($delivery, $courier);

        $delivery->setStatus(DeliveryStatus::ACCEPTED);
        $delivery->setAcceptedAt(new \DateTimeImmutable());

        $this->syncOrderStatus($delivery);

        $this->entityManager->flush();

        return $delivery;
    }

    public function markPickedUp(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        if (DeliveryStatus::ACCEPTED !== $delivery->getStatus()) {
            throw new \RuntimeException('Only accepted deliveries can be marked as picked up.');
        }

        $this->assertAssignedCourier($delivery, $courier);

        $delivery->setStatus(DeliveryStatus::PICKED_UP);
        $delivery->setPickedUpAt(new \DateTimeImmutable());

        $this->syncOrderStatus($delivery);

        $this->entityManager->flush();

        return $delivery;
    }

    public function markOnTheWay(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        if (DeliveryStatus::PICKED_UP !== $delivery->getStatus()) {
            throw new \RuntimeException('Only picked-up deliveries can be marked as on the way.');
        }

        $this->assertAssignedCourier($delivery, $courier);

        $delivery->setStatus(DeliveryStatus::ON_THE_WAY);

        $this->syncOrderStatus($delivery);

        $this->entityManager->flush();

        return $delivery;
    }

    public function markDelivered(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        if (DeliveryStatus::ON_THE_WAY !== $delivery->getStatus()) {
            throw new \RuntimeException('Only deliveries that are on the way can be marked as delivered.');
        }

        $this->assertAssignedCourier($delivery, $courier);

        $delivery->setStatus(DeliveryStatus::DELIVERED);
        $delivery->setDeliveredAt(new \DateTimeImmutable());

        $this->syncOrderStatus($delivery);

        $this->entityManager->flush();

        return $delivery;
    }

    public function cancelDelivery(Delivery $delivery): Delivery
    {
        if (!in_array(
            $delivery->getStatus(),
            [
                DeliveryStatus::PENDING,
                DeliveryStatus::ASSIGNED,
            ],
            true
        )) {
            throw new \RuntimeException('This delivery cannot be cancelled at its current status.');
        }

        $delivery->setStatus(DeliveryStatus::CANCELLED);

        $this->syncOrderStatus($delivery);

        $this->entityManager->flush();

        return $delivery;
    }

    public function failDelivery(
        Delivery $delivery,
        User $courier,
    ): Delivery {
        if (!in_array(
            $delivery->getStatus(),
            [
                DeliveryStatus::ACCEPTED,
                DeliveryStatus::PICKED_UP,
                DeliveryStatus::ON_THE_WAY,
            ],
            true
        )) {
            throw new \RuntimeException('This delivery cannot be marked as failed at its current status.');
        }

        $this->assertAssignedCourier($delivery, $courier);

        $delivery->setStatus(DeliveryStatus::FAILED);

        $this->syncOrderStatus($delivery);

        $this->entityManager->flush();

        return $delivery;
    }

    private function assertAssignedCourier(
        Delivery $delivery,
        User $courier,
    ): void {
        if ($delivery->getCourier()?->getId() !== $courier->getId()) {
            throw new \RuntimeException('You are not assigned to this delivery.');
        }
    }

    private function syncOrderStatus(Delivery $delivery): void
    {
        $order = $delivery->getOrder();

        if (null === $order) {
            throw new \RuntimeException('Delivery must be associated with an order.');
        }

        $orderStatus = match ($delivery->getStatus()) {
            DeliveryStatus::PENDING => OrderStatus::PENDING,
            DeliveryStatus::ASSIGNED,
            DeliveryStatus::ACCEPTED => OrderStatus::CONFIRMED,
            DeliveryStatus::PICKED_UP,
            DeliveryStatus::ON_THE_WAY => OrderStatus::READY_FOR_PICKUP,
            DeliveryStatus::DELIVERED => OrderStatus::COMPLETED,
            DeliveryStatus::CANCELLED,
            DeliveryStatus::FAILED => OrderStatus::CANCELLED,
        };

        $order->setStatus($orderStatus);
    }
}
