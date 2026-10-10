<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Context\ExecutionContextInterface;

/**
 * Where a delivery zone is on the map: its center and the radius it covers.
 * Optional (a zone can exist before it's placed), but all three or none.
 */
trait DeliveryZoneAreaFields
{
    #[Assert\Range(min: -90, max: 90)]
    public ?float $latitude = null;

    #[Assert\Range(min: -180, max: 180)]
    public ?float $longitude = null;

    /** Between 100 m and 50 km. */
    #[Assert\Range(min: 0.1, max: 50)]
    public ?float $radiusKm = null;

    #[Assert\Callback]
    public function validateArea(ExecutionContextInterface $context): void
    {
        $set = array_filter([$this->latitude, $this->longitude, $this->radiusKm], static fn ($v) => null !== $v);

        if (0 !== \count($set) && 3 !== \count($set)) {
            $context->buildViolation('Place the zone on the map with its radius, or leave all three empty.')
                ->atPath('radiusKm')
                ->addViolation();
        }
    }
}
