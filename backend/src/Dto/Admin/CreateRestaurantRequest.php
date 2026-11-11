<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class CreateRestaurantRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $name = null;

    #[Assert\Length(max: 5000)]
    public ?string $description = null;

    public bool $isAvailable = true;

    #[Assert\Choice(choices: ['RESTAURANT', 'GROCERY'])]
    public string $type = 'RESTAURANT';

    /**
     * Ids of its restaurant categories ("Pizza", "Sucré"...). Left out:
     * none.
     *
     * @var int[]
     */
    #[Assert\All([new Assert\Type('int'), new Assert\Positive()])]
    #[Assert\Count(max: 20)]
    public array $categoryIds = [];
}
