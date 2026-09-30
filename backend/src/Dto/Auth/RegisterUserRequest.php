<?php

namespace App\Dto\Auth;

use App\Validator\PhoneFormat;
use Symfony\Component\Validator\Constraints as Assert;

final class RegisterUserRequest
{
    #[Assert\NotBlank(message: 'Nom requis.', normalizer: 'trim')]
    #[Assert\Length(max: 255, maxMessage: 'Nom trop long.')]
    public string $name = '';

    #[Assert\NotBlank(message: 'Numéro requis.')]
    #[Assert\Length(max: 255)]
    #[Assert\Regex(pattern: PhoneFormat::PATTERN, message: PhoneFormat::MESSAGE)]
    public string $phone = '';

    #[Assert\NotBlank(message: 'Mot de passe requis.')]
    #[Assert\Length(min: 8, max: 4096, minMessage: 'Le mot de passe doit contenir au moins 8 caractères.')]
    public string $password = '';
}
