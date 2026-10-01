<?php

namespace App\Dto\Auth;

use Symfony\Component\Validator\Constraints as Assert;

final class DeleteAccountRequest
{
    /** Asked again, so a phone left unlocked can't delete the account. */
    #[Assert\NotBlank(message: 'Mot de passe requis.')]
    public string $password = '';
}
