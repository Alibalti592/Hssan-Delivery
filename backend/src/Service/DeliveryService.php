<?php

namespace App\Service;

use App\Entity\Delivery;
use App\Entity\User;
use App\Enum\DeliveryStatus;
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
    User $courier
): Delivery {
    if ($delivery->getStatus() !== DeliveryStatus::PENDING) {
        throw new \RuntimeException(
            'Only pending deliveries can be assigned.'
        );
    }

    if (!in_array('ROLE_LIVREUR', $courier->getRoles(), true)) {
        throw new \RuntimeException(
            'The selected user is not a courier.'
        );
    }

    $delivery->setCourier($courier);
    $delivery->setStatus(DeliveryStatus::ASSIGNED);
    $delivery->setAssignedAt(new \DateTimeImmutable());

    $this->entityManager->flush();

    return $delivery;
}
public function acceptDelivery(
    Delivery $delivery,
    User $courier
): Delivery {
    if ($delivery->getStatus() !== DeliveryStatus::ASSIGNED) {
        throw new \RuntimeException(
            'Only assigned deliveries can be accepted.'
        );
    }

    if ($delivery->getCourier()?->getId() !== $courier->getId()) {
        throw new \RuntimeException(
            'You are not assigned to this delivery.'
        );
    }

    $delivery->setStatus(DeliveryStatus::ACCEPTED);
    $delivery->setAcceptedAt(new \DateTimeImmutable());

    $this->entityManager->flush();

    return $delivery;
}
public function markPickedUp(
    Delivery $delivery,
    User $courier
): Delivery {
    if ($delivery->getStatus() !== DeliveryStatus::ACCEPTED) {
        throw new \RuntimeException(
            'Only accepted deliveries can be marked as picked up.'
        );
    }

    if ($delivery->getCourier()?->getId() !== $courier->getId()) {
        throw new \RuntimeException(
            'You are not assigned to this delivery.'
        );
    }

    $delivery->setStatus(DeliveryStatus::PICKED_UP);
    $delivery->setPickedUpAt(new \DateTimeImmutable());

    $this->entityManager->flush();

    return $delivery;
}
public function markOnTheWay(
    Delivery $delivery,
    User $courier
): Delivery {
    if ($delivery->getStatus() !== DeliveryStatus::PICKED_UP) {
        throw new \RuntimeException(
            'Only picked-up deliveries can be marked as on the way.'
        );
    }

    if ($delivery->getCourier()?->getId() !== $courier->getId()) {
        throw new \RuntimeException(
            'You are not assigned to this delivery.'
        );
    }

    $delivery->setStatus(DeliveryStatus::ON_THE_WAY);

    $this->entityManager->flush();

    return $delivery;
}
public function markDelivered(
    Delivery $delivery,
    User $courier
): Delivery {
    if ($delivery->getStatus() !== DeliveryStatus::ON_THE_WAY) {
        throw new \RuntimeException(
            'Only deliveries that are on the way can be marked as delivered.'
        );
    }

    if ($delivery->getCourier()?->getId() !== $courier->getId()) {
        throw new \RuntimeException(
            'You are not assigned to this delivery.'
        );
    }

    $delivery->setStatus(DeliveryStatus::DELIVERED);
    $delivery->setDeliveredAt(new \DateTimeImmutable());

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
        throw new \RuntimeException(
            'This delivery cannot be cancelled at its current status.'
        );
    }

    $delivery->setStatus(DeliveryStatus::CANCELLED);

    $this->entityManager->flush();

    return $delivery;
}
public function failDelivery(
    Delivery $delivery,
    User $courier
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
        throw new \RuntimeException(
            'This delivery cannot be marked as failed at its current status.'
        );
    }

    if ($delivery->getCourier()?->getId() !== $courier->getId()) {
        throw new \RuntimeException(
            'You are not assigned to this delivery.'
        );
    }

    $delivery->setStatus(DeliveryStatus::FAILED);

    $this->entityManager->flush();

    return $delivery;
}
}