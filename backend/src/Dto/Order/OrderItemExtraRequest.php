<?php

namespace App\Dto\Order;

use Symfony\Component\Validator\Constraints as Assert;

/**
 * One thing added to an order line: "Harissa" from the product's "Sauces".
 */
final class OrderItemExtraRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 50)]
    public ?string $group = null;

    #[Assert\NotBlank]
    #[Assert\Length(max: 50)]
    public ?string $choice = null;
}
