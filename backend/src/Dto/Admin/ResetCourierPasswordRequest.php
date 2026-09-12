<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class ResetCourierPasswordRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(min: 8, max: 4096)]
    public string $password = '';
}
