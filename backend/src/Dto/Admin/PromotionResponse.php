<?php

namespace App\Dto\Admin;

use App\Entity\Promotion;
use App\Service\PhotoUploader;

final class PromotionResponse
{
    public static function fromEntity(Promotion $promotion): array
    {
        $restaurant = $promotion->getRestaurant();

        return [
            'id' => $promotion->getId(),
            'title' => $promotion->getTitle(),
            'description' => $promotion->getDescription(),
            'photoUrl' => PhotoUploader::url($promotion->getImageFilename(), 'promotions'),
            'discountType' => $promotion->getDiscountType()->value,
            'discountValue' => $promotion->getDiscountValue(),
            'promoCode' => $promotion->getPromoCode(),
            'startAt' => $promotion->getStartAt()?->format(\DateTimeInterface::ATOM),
            'endAt' => $promotion->getEndAt()?->format(\DateTimeInterface::ATOM),
            'isActive' => $promotion->isActive(),
            'restaurantId' => $restaurant?->getId(),
            'restaurantName' => $restaurant?->getName(),
            'createdAt' => $promotion->getCreatedAt()?->format(\DateTimeInterface::ATOM),
            'updatedAt' => $promotion->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
        ];
    }
}
