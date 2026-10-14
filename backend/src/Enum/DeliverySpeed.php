<?php

namespace App\Enum;

/**
 * How fast the client wants it: standard (30–40 min) or express (15–20 min,
 * for a flat extra on the delivery fee). An express order goes first: the
 * dispatch queue lists it on top, and a courier already on a standard
 * delivery can take one express order on top of it.
 */
enum DeliverySpeed: string
{
    case STANDARD = 'STANDARD';
    case EXPRESS = 'EXPRESS';

    /** What express adds to the zone's delivery fee, in DT. */
    public const EXPRESS_FEE = '1.000';

    /** What this speed adds to the zone's delivery fee, in DT. */
    public function extraFee(): string
    {
        return self::EXPRESS === $this ? self::EXPRESS_FEE : '0.000';
    }
}
