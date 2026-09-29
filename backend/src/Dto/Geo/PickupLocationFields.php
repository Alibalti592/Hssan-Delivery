<?php

namespace App\Dto\Geo;

use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Context\ExecutionContextInterface;

/**
 * Where the courier collects a Colis, when the client placed a pin — see
 * DeliveryLocationFields.
 */
trait PickupLocationFields
{
    #[Assert\Range(min: -90, max: 90)]
    public ?float $pickupLatitude = null;

    #[Assert\Range(min: -180, max: 180)]
    public ?float $pickupLongitude = null;

    #[Assert\Callback]
    public function validatePickupLocation(ExecutionContextInterface $context): void
    {
        if ((null === $this->pickupLatitude) !== (null === $this->pickupLongitude)) {
            $context->buildViolation('Latitude and longitude go together.')
                ->atPath('pickupLatitude')
                ->addViolation();
        }
    }
}
