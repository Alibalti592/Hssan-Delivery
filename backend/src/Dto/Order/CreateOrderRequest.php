<?php

namespace App\Dto\Order;

use App\Dto\Geo\DeliveryLocationFields;
use Symfony\Component\Validator\Constraints as Assert;

final class CreateOrderRequest
{
    use DeliveryLocationFields;
    use DeliverySpeedField;

    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $restaurantId = null;

    /**
     * @var OrderItemRequest[]
     */
    #[Assert\Count(min: 1, max: 50)]
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

    /** A promotion code the client typed at checkout, if any. */
    #[Assert\Length(max: 50)]
    public ?string $promoCode = null;

    /**
     * Made by the app once per checkout and sent again when it retries:
     * when the answer to the first try was lost on a weak network, the
     * order it placed comes back instead of a second one.
     */
    #[Assert\Length(max: 64)]
    #[Assert\Regex(pattern: '/^[A-Za-z0-9_-]+$/')]
    public ?string $clientRequestId = null;
}