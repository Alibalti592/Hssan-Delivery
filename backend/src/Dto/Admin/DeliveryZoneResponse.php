<?php

namespace App\Dto\Admin;

use App\Entity\DeliveryZone;

final class DeliveryZoneResponse
{
    public static function fromEntity(DeliveryZone $zone): array
    {
        return [
            'id' => $zone->getId(),
            'name' => $zone->getName(),
            'fee' => $zone->getFee(),
            'latitude' => $zone->getLatitude(),
            'longitude' => $zone->getLongitude(),
            'radiusKm' => $zone->getRadiusKm(),
            'createdAt' => $zone->getCreatedAt()?->format(\DateTimeInterface::ATOM),
            'updatedAt' => $zone->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
        ];
    }
}
