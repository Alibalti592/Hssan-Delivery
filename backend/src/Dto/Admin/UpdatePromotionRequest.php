<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Context\ExecutionContextInterface;

final class UpdatePromotionRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $title = null;

    #[Assert\Length(max: 5000)]
    public ?string $description = null;

    #[Assert\NotNull]
    #[Assert\Choice(choices: ['PERCENTAGE', 'FIXED_AMOUNT', 'FIXED_PRICE'])]
    public ?string $discountType = null;

    // Bounded to 7 integer digits to match the `discountValue` column's
    // precision: 10, scale: 3 — an out-of-range value would otherwise pass
    // this check and fail at flush() with a raw DBAL exception instead of
    // a clean 422. (A PERCENTAGE value over 100 is caught separately, in
    // PromotionService::applyRequest.) For FIXED_PRICE it is the offer's
    // price.
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

    // Optional: without one the promotion stays up until the admin hides
    // it (isActive), e.g. an offer "jusqu'à épuisement du stock".
    public ?\DateTimeImmutable $endAt = null;

    public bool $isActive = true;

    #[Assert\Positive]
    public ?int $restaurantId = null;

    /**
     * FIXED_PRICE only: what the offer includes, one line per item.
     *
     * @var list<string>
     */
    #[Assert\Count(max: 10)]
    #[Assert\All([
        new Assert\Type('string'),
        new Assert\NotBlank(normalizer: 'trim'),
        new Assert\Length(max: 100),
    ])]
    public array $items = [];

    #[Assert\Callback]
    public function validateOffer(ExecutionContextInterface $context): void
    {
        if ('FIXED_PRICE' !== $this->discountType) {
            return;
        }

        // The offer is ordered as one of the restaurant's products, so it
        // needs a restaurant -- and a price a client can actually pay.
        if (null === $this->restaurantId) {
            $context->buildViolation('An offer must belong to a restaurant.')
                ->atPath('restaurantId')
                ->addViolation();
        }

        if (null !== $this->discountValue && is_numeric($this->discountValue) && (float) $this->discountValue <= 0) {
            $context->buildViolation('An offer price must be greater than zero.')
                ->atPath('discountValue')
                ->addViolation();
        }
    }
}
