<?php

namespace App\Dto\Admin;

use App\Entity\Restaurant;

final class RestaurantResponse
{
    public static function fromEntity(Restaurant $restaurant): array
    {
        return [
            'id' => $restaurant->getId(),
            'name' => $restaurant->getName(),
            'description' => $restaurant->getDescription(),
            'isAvailable' => $restaurant->isAvailable(),
            'createdAt' => $restaurant->getCreatedAt()?->format(\DateTimeInterface::ATOM),
            'updatedAt' => $restaurant->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
        ];
    }
}