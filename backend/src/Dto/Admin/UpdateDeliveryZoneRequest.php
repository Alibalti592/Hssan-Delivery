<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class UpdateDeliveryZoneRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $name = null;

    #[Assert\NotBlank]
    #[Assert\Regex(
        pattern: '/^\d+(\.\d{1,3})?$/',
        message: 'Fee must be a valid positive decimal with up to 3 decimal places.'
    )]
    public ?string $fee = null;
}
