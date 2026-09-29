<?php

namespace App\Dto\Address;

use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Context\ExecutionContextInterface;

/**
 * The zone that prices deliveries to a saved address, and the pin the
 * client dropped on the map. All optional: addresses saved before these
 * existed have none, and the app asks for the zone at checkout instead.
 */
trait AddressLocationFields
{
    #[Assert\Positive]
    public ?int $deliveryZoneId = null;

    #[Assert\Range(min: -90, max: 90)]
    public ?float $latitude = null;

    #[Assert\Range(min: -180, max: 180)]
    public ?float $longitude = null;

    #[Assert\Callback]
    public function validateLocation(ExecutionContextInterface $context): void
    {
        if ((null === $this->latitude) !== (null === $this->longitude)) {
            $context->buildViolation('Latitude and longitude go together.')
                ->atPath('latitude')
                ->addViolation();
        }
    }
}
