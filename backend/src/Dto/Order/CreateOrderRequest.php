<?php

namespace App\Dto\Order;

use Symfony\Component\Validator\Constraints as Assert;

final class CreateOrderRequest
{
    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $restaurantId = null;

    /**
     * @var OrderItemRequest[]
     */
    #[Assert\Count(min: 1)]
    #[Assert\All([
        new Assert\Type(type: OrderItemRequest::class),
    ])]
    #[Assert\Valid]
    public array $items = [];

    #[Assert\Length(max: 2000)]
    public ?string $note = null;

    #[Assert\NotBlank]
    #[Assert\Length(max: 1000)]
    public string $deliveryAddress = '';

    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $deliveryZoneId = null;
}