<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

final class UpdateCourierActiveRequest
{
    #[Assert\NotNull]
    #[Assert\Type('bool')]
    public ?bool $isActive = null;
}
