<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class UpdateRestaurantRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public string $name = '';

    #[Assert\Length(max: 2000)]
    public ?string $description = null;

    #[Assert\Type('bool')]
    public bool $isAvailable = true;
}