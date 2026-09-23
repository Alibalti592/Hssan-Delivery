<?php

namespace App\Dto\Admin;

use App\Validator\PhoneFormat;
use Symfony\Component\Validator\Constraints as Assert;

final class CreateCourierRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public string $name = '';

    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    #[Assert\Regex(pattern: PhoneFormat::PATTERN, message: PhoneFormat::MESSAGE)]
    public string $phone = '';

    #[Assert\NotBlank]
    #[Assert\Length(min: 8, max: 4096)]
    public string $password = '';
}