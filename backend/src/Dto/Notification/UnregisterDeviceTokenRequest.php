<?php

namespace App\Dto\Notification;

use Symfony\Component\Validator\Constraints as Assert;

final class UnregisterDeviceTokenRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public string $token = '';
}
