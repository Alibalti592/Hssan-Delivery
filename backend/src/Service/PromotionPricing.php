<?php

namespace App\Service;

use App\Entity\Promotion;
use App\Entity\Restaurant;
use App\Enum\DiscountType;
use App\Exception\InvalidOperationException;
use App\Repository\PromotionRepository;
use App\Util\Money;

/**
 * Which promotion takes money off a restaurant or grocery order, and how
 * much. Only percentage and fixed-amount promotions count here: a
 * fixed-price offer is already its own product at its own price.
 *
 * - A promotion without a code applies by itself to every order from its
 *   restaurant (or from any, when it has no restaurant).
 * - A promotion with a code applies only when the client enters that code.
 * - One promotion per order: the one giving the client the most.
 */
final class PromotionPricing
{
    public function __construct(
        private readonly PromotionRepository $promotionRepository,
    ) {
    }

    /**
     * @param int $baseMillimes what the discount applies to: the items,
     *                          without offers or the delivery fee
     *
     * @return array{promotion: Promotion, millimes: int}|null
     *
     * @throws InvalidOperationException when $code matches no promotion
     *                                   usable for this order
     */
    public function bestDiscount(Restaurant $restaurant, int $baseMillimes, ?string $code, \DateTimeImmutable $now): ?array
    {
        $candidates = array_filter(
            $this->promotionRepository->findCurrentlyValid($now),
            static fn (Promotion $promotion) => DiscountType::FIXED_PRICE !== $promotion->getDiscountType()
                && null === $promotion->getPromoCode()
                && self::appliesTo($promotion, $restaurant),
        );

        $code = null === $code ? '' : trim($code);

        if ('' !== $code) {
            $candidates[] = $this->promotionForCode($code, $restaurant, $now);
        }

        $best = null;

        foreach ($candidates as $promotion) {
            $millimes = self::discountMillimes($promotion, $baseMillimes);

            if ($millimes > 0 && (null === $best || $millimes > $best['millimes'])) {
                $best = ['promotion' => $promotion, 'millimes' => $millimes];
            }
        }

        return $best;
    }

    private function promotionForCode(string $code, Restaurant $restaurant, \DateTimeImmutable $now): Promotion
    {
        $matches = array_filter(
            $this->promotionRepository->findCurrentlyValid($now),
            static fn (Promotion $promotion) => DiscountType::FIXED_PRICE !== $promotion->getDiscountType()
                && null !== $promotion->getPromoCode()
                && 0 === strcasecmp($promotion->getPromoCode(), $code),
        );

        if ([] === $matches) {
            throw new InvalidOperationException('Ce code promo n\'est pas valable.');
        }

        foreach ($matches as $promotion) {
            if (self::appliesTo($promotion, $restaurant)) {
                return $promotion;
            }
        }

        $elsewhere = reset($matches)->getRestaurant()?->getName();

        throw new InvalidOperationException("Ce code est valable seulement chez {$elsewhere}.");
    }

    private static function appliesTo(Promotion $promotion, Restaurant $restaurant): bool
    {
        $only = $promotion->getRestaurant();

        return null === $only || $only->getId() === $restaurant->getId();
    }

    private static function discountMillimes(Promotion $promotion, int $baseMillimes): int
    {
        if ($baseMillimes <= 0) {
            return 0;
        }

        $value = (string) $promotion->getDiscountValue();

        $millimes = DiscountType::PERCENTAGE === $promotion->getDiscountType()
            // "10.000" is 10 %, worked out to the millime.
            ? intdiv($baseMillimes * min(Money::toMillimes($value), 100_000), 100_000)
            : Money::toMillimes($value);

        return max(0, min($millimes, $baseMillimes));
    }
}
