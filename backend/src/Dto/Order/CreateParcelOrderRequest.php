<?php

namespace App\Dto\Order;

use Symfony\Component\Validator\Constraints as Assert;

final class CreateParcelOrderRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 1000)]
    public string $pickupAddress = '';

    #[Assert\NotBlank]
    #[Assert\Length(max: 1000)]
    public string $deliveryAddress = '';

    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public string $recipientName = '';

    #[Assert\NotBlank]
    #[Assert\Length(max: 30)]
    public string $recipientPhone = '';

    #[Assert\Length(max: 2000)]
    public ?string $note = null;

    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $deliveryZoneId = null;
}
