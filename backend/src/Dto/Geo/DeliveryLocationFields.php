<?php

namespace App\Dto\Geo;

use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Context\ExecutionContextInterface;

/**
 * Where the courier drops off, as the pin the client placed on the map —
 * optional (typed addresses and older app versions have none), but both
 * coordinates or neither.
 */
trait DeliveryLocationFields
{
    #[Assert\Range(min: -90, max: 90)]
    public ?float $deliveryLatitude = null;

    #[Assert\Range(min: -180, max: 180)]
    public ?float $deliveryLongitude = null;

    #[Assert\Callback]
    public function validateDeliveryLocation(ExecutionContextInterface $context): void
    {
        if ((null === $this->deliveryLatitude) !== (null === $this->deliveryLongitude)) {
            $context->buildViolation('Latitude and longitude go together.')
                ->atPath('deliveryLatitude')
                ->addViolation();
        }
    }
}
