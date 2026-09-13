<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class UpdateCourierLocationRequest
{
    #[Assert\NotNull]
    #[Assert\Range(min: -90, max: 90)]
    public ?float $latitude = null;

    #[Assert\NotNull]
    #[Assert\Range(min: -180, max: 180)]
    public ?float $longitude = null;
}
