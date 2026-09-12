<?php

namespace App\Dto\Auth;

use Symfony\Component\Validator\Constraints as Assert;

final class ChangePasswordRequest
{
    #[Assert\NotBlank]
    public string $currentPassword = '';

    #[Assert\NotBlank]
    #[Assert\Length(min: 8, max: 4096)]
    public string $newPassword = '';
}
