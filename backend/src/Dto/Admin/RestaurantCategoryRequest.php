<?php

namespace App\Dto\Admin;

use App\Entity\RestaurantCategory;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * Body of both creating and editing a restaurant category; its image has
 * its own upload endpoint.
 */
final class RestaurantCategoryRequest
{
    #[Assert\NotBlank(normalizer: 'trim')]
    #[Assert\Length(max: 100)]
    public ?string $name = null;

    #[Assert\Choice(choices: RestaurantCategory::ICONS)]
    public string $icon = RestaurantCategory::DEFAULT_ICON;

    #[Assert\NotNull]
    #[Assert\Type('int')]
    #[Assert\Range(min: 0, max: 1000)]
    public ?int $position = null;
}
