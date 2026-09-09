<?php

namespace App\Dto\Address;

use Symfony\Component\Validator\Constraints as Assert;

final class CreateAddressRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $label = null;

    #[Assert\NotBlank]
    #[Assert\Length(max: 1000)]
    public ?string $addressLine = null;

    #[Assert\Length(max: 1000)]
    public ?string $instructions = null;

    public bool $isDefault = false;
}
