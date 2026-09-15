<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class CreateProductRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $name = null;

    #[Assert\Length(max: 5000)]
    public ?string $description = null;

    // Bounded to 7 integer digits to match the `price` column's
    // precision: 10, scale: 3 — an out-of-range value would otherwise pass
    // this check and fail at flush() with a raw DBAL exception instead of
    // a clean 422.
    #[Assert\NotBlank]
    #[Assert\Regex(
        pattern: '/^\d{1,7}(\.\d{1,3})?$/',
        message: 'Price must be a valid positive decimal with up to 3 decimal places.'
    )]
    public ?string $price = null;

    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $categoryId = null;

    public bool $isAvailable = true;
}