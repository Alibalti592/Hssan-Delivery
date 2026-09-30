<?php

namespace App\Dto\Auth;

use Symfony\Component\Validator\Constraints as Assert;

final class ChangePasswordRequest
{
    #[Assert\NotBlank(message: 'Mot de passe actuel requis.')]
    public string $currentPassword = '';

    #[Assert\NotBlank(message: 'Nouveau mot de passe requis.')]
    #[Assert\Length(min: 8, max: 4096, minMessage: 'Le mot de passe doit contenir au moins 8 caractères.')]
    public string $newPassword = '';
}
