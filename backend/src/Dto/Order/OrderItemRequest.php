<?php

namespace App\Dto\Order;

use Symfony\Component\Validator\Constraints as Assert;

final class OrderItemRequest
{
    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $productId = null;

    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $quantity = null;
}