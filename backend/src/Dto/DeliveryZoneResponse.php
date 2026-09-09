<?php

namespace App\Dto;

use App\Entity\DeliveryZone;

final class DeliveryZoneResponse
{
    public static function fromEntity(DeliveryZone $zone): array
    {
        return [
            'id' => $zone->getId(),
            'name' => $zone->getName(),
            'fee' => $zone->getFee(),
        ];
    }
}
