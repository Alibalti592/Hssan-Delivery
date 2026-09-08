<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class UpdateRestaurantAvailabilityRequest
{
    #[Assert\NotNull]
    #[Assert\Type('bool')]
    public ?bool $isAvailable = null;
}