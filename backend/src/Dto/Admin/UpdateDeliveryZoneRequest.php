<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class UpdateDeliveryZoneRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $name = null;

    // Bounded to 7 integer digits to match the `fee` column's
    // precision: 10, scale: 3 — an out-of-range value would otherwise pass
    // this check and fail at flush() with a raw DBAL exception instead of
    // a clean 422.
    #[Assert\NotBlank]
    #[Assert\Regex(
        pattern: '/^\d{1,7}(\.\d{1,3})?$/',
        message: 'Fee must be a valid positive decimal with up to 3 decimal places.'
    )]
    public ?string $fee = null;
}
