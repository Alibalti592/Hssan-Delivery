<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class CreatePromotionRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $title = null;

    #[Assert\Length(max: 5000)]
    public ?string $description = null;

    #[Assert\NotNull]
    #[Assert\Choice(choices: ['PERCENTAGE', 'FIXED_AMOUNT'])]
    public ?string $discountType = null;

    #[Assert\NotBlank]
    #[Assert\Regex(
        pattern: '/^\d+(\.\d{1,3})?$/',
        message: 'Discount value must be a valid positive decimal with up to 3 decimal places.'
    )]
    public ?string $discountValue = null;

    #[Assert\Length(max: 50)]
    public ?string $promoCode = null;

    #[Assert\NotNull]
    public ?\DateTimeImmutable $startAt = null;

    #[Assert\NotNull]
    public ?\DateTimeImmutable $endAt = null;

    public bool $isActive = true;

    #[Assert\Positive]
    public ?int $restaurantId = null;
}
