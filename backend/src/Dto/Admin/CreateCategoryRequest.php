<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class CreateCategoryRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $name = null;
}