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
            'type' => $restaurant->getType()->value,
            'photoUrl' => PhotoUploader::url($restaurant->getPhotoFilename(), 'restaurants'),
            // What it serves, for browsing (not its menu sections).
            'categories' => array_map(
                static fn ($category) => RestaurantCategoryResponse::fromEntity($category),
                $restaurant->getRestaurantCategories()->getValues()
            ),
            'createdAt' => $restaurant->getCreatedAt()?->format(\DateTimeInterface::ATOM),
            'updatedAt' => $restaurant->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
        ];
    }
}
