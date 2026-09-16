<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class UpdatePromotionRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $title = null;

    #[Assert\Length(max: 5000)]
    public ?string $description = null;

    #[Assert\NotNull]
    #[Assert\Choice(choices: ['PERCENTAGE', 'FIXED_AMOUNT'])]
    public ?string $discountType = null;

    // Bounded to 7 integer digits to match the `discountValue` column's
    // precision: 10, scale: 3 — an out-of-range value would otherwise pass
    // this check and fail at flush() with a raw DBAL exception instead of
    // a clean 422. (A PERCENTAGE value over 100 is caught separately, in
    // PromotionService::applyRequest.)
    #[Assert\NotBlank]
    #[Assert\Regex(
        pattern: '/^\d{1,7}(\.\d{1,3})?$/',
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
