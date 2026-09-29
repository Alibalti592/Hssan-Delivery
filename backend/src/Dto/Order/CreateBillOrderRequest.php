<?php

namespace App\Dto\Order;

use App\Validator\PhoneFormat;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * A Factures order: a courier collects the cash (and the bill) at the
 * client's address, pays it at the provider's counter, and brings the
 * receipt back. Which of reference / recipient is required depends on the
 * provider's kind — checked in OrderService::createBillOrder.
 */
final class CreateBillOrderRequest
{
    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $providerId = null;

    #[Assert\Length(max: 100)]
    public ?string $reference = null;

    #[Assert\NotBlank]
    #[Assert\Regex(
        pattern: '/^\d{1,7}(\.\d{1,3})?$/',
        message: 'Amount must be a valid positive decimal with up to 3 decimal places.'
    )]
    public ?string $amount = null;

    #[Assert\Length(max: 255)]
    public ?string $recipientName = null;

    #[Assert\Length(max: 30)]
    #[Assert\Regex(pattern: PhoneFormat::PATTERN, message: PhoneFormat::MESSAGE)]
    public ?string $recipientPhone = null;

    /**
     * Where the courier collects the cash and brings the receipt back.
     */
    #[Assert\NotBlank]
    #[Assert\Length(max: 1000)]
    public string $address = '';

    #[Assert\Length(max: 2000)]
    public ?string $note = null;

    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $deliveryZoneId = null;
}
