<?php

namespace App\Dto\Admin;

use App\Entity\Category;

final class CategoryResponse
{
    public static function fromEntity(Category $category): array
    {
        return [
            'id' => $category->getId(),
            'name' => $category->getName(),
            'restaurantId' => $category->getRestaurant()?->getId(),
            'createdAt' => $category->getCreatedAt()?->format(\DateTimeInterface::ATOM),
            'updatedAt' => $category->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
        ];
    }
}