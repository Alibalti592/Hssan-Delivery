<?php

namespace App\Dto\Admin;

use App\Entity\Product;

final class ProductResponse
{
    public static function fromEntity(Product $product): array
    {
        return [
            'id' => $product->getId(),
            'name' => $product->getName(),
            'description' => $product->getDescription(),
            'price' => $product->getPrice(),
            'isAvailable' => $product->isAvailable(),
            'restaurantId' => $product->getRestaurant()?->getId(),
            'categoryId' => $product->getCategory()?->getId(),
            'createdAt' => $product->getCreatedAt()?->format(
                \DateTimeInterface::ATOM
            ),
            'updatedAt' => $product->getUpdatedAt()?->format(
                \DateTimeInterface::ATOM
            ),
        ];
    }
}