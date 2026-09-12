<?php

namespace App\Dto\Notification;

use Symfony\Component\Validator\Constraints as Assert;

final class RegisterDeviceTokenRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public string $token = '';

    #[Assert\Length(max: 20)]
    public ?string $platform = null;
}
