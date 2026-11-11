<?php

namespace App\Dto\Admin;

use App\Entity\RestaurantCategory;
use App\Service\PhotoUploader;
use App\Service\RestaurantCategoryService;

final class RestaurantCategoryResponse
{
    public static function fromEntity(RestaurantCategory $category): array
    {
        return [
            'id' => $category->getId(),
            'name' => $category->getName(),
            'icon' => $category->getIcon(),
            'imageUrl' => PhotoUploader::url($category->getImageFilename(), RestaurantCategoryService::IMAGE_SUBDIRECTORY),
            'position' => $category->getPosition(),
        ];
    }
}
