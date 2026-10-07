<?php

namespace App\Dto\Admin;

use App\Validator\PhoneFormat;
use Symfony\Component\Validator\Constraints as Assert;

final class ResetUserPasswordRequest
{
    #[Assert\NotBlank(message: 'Numéro requis.')]
    #[Assert\Length(max: 255)]
    #[Assert\Regex(pattern: PhoneFormat::PATTERN, message: PhoneFormat::MESSAGE)]
    public string $phone = '';

    #[Assert\NotBlank(message: 'Mot de passe requis.')]
    #[Assert\Length(min: 8, max: 4096, minMessage: 'Le mot de passe doit contenir au moins 8 caractères.')]
    public string $password = '';
}
