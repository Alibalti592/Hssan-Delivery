<?php

namespace App\Dto\Admin;

use App\Entity\Delivery;
use App\Entity\User;

/**
 * What the admin courier map is allowed to show for one courier: enough to
 * place and label a marker, nothing else — no phone number, no address, no
 * account/history details (see AdminRestaurantController-style responses
 * for contrast, which are allowed to be richer since they're not exposing a
 * person's live-ish position).
 */
final class CourierLocationResponse
{
    public static function fromCourier(User $courier, string $status, ?float $latitude, ?float $longitude, ?\DateTimeImmutable $updatedAt, ?Delivery $currentDelivery): array
    {
        return [
            'courierId' => $courier->getId(),
            'name' => $courier->getName(),
            'status' => $status,
            'latitude' => $latitude,
            'longitude' => $longitude,
            'updatedAt' => $updatedAt?->format(\DateTimeInterface::ATOM),
            'currentDeliveryId' => $currentDelivery?->getId(),
        ];
    }
}
