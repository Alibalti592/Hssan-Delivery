<?php

namespace App\Dto\Order;

use App\Enum\DeliverySpeed;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * Standard or express — optional, standard by default (and for older app
 * versions, which don't send it).
 */
trait DeliverySpeedField
{
    #[Assert\Choice(callback: [self::class, 'deliverySpeeds'])]
    public string $deliverySpeed = 'STANDARD';

    /** @return string[] */
    public static function deliverySpeeds(): array
    {
        return array_map(static fn (DeliverySpeed $s) => $s->value, DeliverySpeed::cases());
    }

    public function speed(): DeliverySpeed
    {
        return DeliverySpeed::from($this->deliverySpeed);
    }
}
