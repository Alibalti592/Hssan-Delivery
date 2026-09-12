<?php

namespace App\Dto\Admin;

use App\Entity\Restaurant;
use App\Service\PhotoUploader;

final class RestaurantResponse
{
    public static function fromEntity(Restaurant $restaurant): array
    {
        return [
            'id' => $restaurant->getId(),
            'name' => $restaurant->getName(),
            'description' => $restaurant->getDescription(),
            'isAvailable' => $restaurant->isAvailable(),
            'photoUrl' => PhotoUploader::url($restaurant->getPhotoFilename(), 'restaurants'),
            'createdAt' => $restaurant->getCreatedAt()?->format(\DateTimeInterface::ATOM),
            'updatedAt' => $restaurant->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
        ];
    }
}
