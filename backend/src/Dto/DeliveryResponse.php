<?php

namespace App\Dto;

use App\Entity\Delivery;

final class DeliveryResponse
{
    public static function fromEntity(Delivery $delivery): array
    {
        return [
            'id' => $delivery->getId(),
            'orderId' => $delivery->getOrder()?->getId(),
            'status' => $delivery->getStatus()->value,
            'courierId' => $delivery->getCourier()?->getId(),
            'assignedAt' => $delivery->getAssignedAt()?->format(\DateTimeInterface::ATOM),
            'acceptedAt' => $delivery->getAcceptedAt()?->format(\DateTimeInterface::ATOM),
            'pickedUpAt' => $delivery->getPickedUpAt()?->format(\DateTimeInterface::ATOM),
            'deliveredAt' => $delivery->getDeliveredAt()?->format(\DateTimeInterface::ATOM),
            'createdAt' => $delivery->getCreatedAt()?->format(\DateTimeInterface::ATOM),
        ];
    }
}
