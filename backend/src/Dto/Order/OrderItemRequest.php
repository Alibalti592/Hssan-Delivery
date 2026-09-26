<?php

namespace App\Dto\Order;

use Symfony\Component\Validator\Constraints as Assert;

final class OrderItemRequest
{
    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $productId = null;

    // Upper bound guards against Money::toMillimes() * quantity overflowing
    // into float arithmetic for an absurd value — no real order needs more
    // than this of one product.
    #[Assert\NotNull]
    #[Assert\Range(min: 1, max: 100)]
    public ?int $quantity = null;

    // Name of the chosen option ("Familiale", "12 pièces"...), required for
    // a product that has options and rejected for one that doesn't — see
    // OrderService::createOrder().
    #[Assert\Length(max: 50)]
    public ?string $option = null;
}