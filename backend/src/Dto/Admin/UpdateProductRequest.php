<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class UpdateProductRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $name = null;

    #[Assert\Length(max: 5000)]
    public ?string $description = null;

    #[Assert\NotBlank]
    #[Assert\Regex(
        pattern: '/^\d+(\.\d{1,3})?$/',
        message: 'Price must be a valid positive decimal with up to 3 decimal places.'
    )]
    public ?string $price = null;

    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $categoryId = null;

    public bool $isAvailable = true;
}