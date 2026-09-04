<?php

namespace App\Dto;

use Symfony\Component\Validator\Constraints as Assert;

final class RegisterUserRequest
{
    #[Assert\NotBlank]
    #[Assert\Email]
    public string $email = '';

    #[Assert\NotBlank]
    #[Assert\Length(min: 8, max: 4096)]
    public string $password = '';

    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public string $name = '';

    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public string $phone = '';

    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public string $address = '';

    /**
     * Which side of the platform this account is for. Admin accounts are
     * never created through public registration.
     */
    #[Assert\NotBlank]
    #[Assert\Choice(choices: ['CLIENT', 'LIVREUR'])]
    public string $accountType = 'CLIENT';
}
