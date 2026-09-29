<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

/**
 * Body of both creating and editing a bill provider; the logo has its own
 * upload endpoint, and visibility its own toggle.
 */
final class BillProviderRequest
{
    #[Assert\NotBlank(normalizer: 'trim')]
    #[Assert\Length(max: 100)]
    public ?string $name = null;

    #[Assert\NotBlank]
    #[Assert\Choice(choices: ['BILL', 'TRANSFER'])]
    public ?string $kind = null;

    #[Assert\NotNull]
    #[Assert\Type('int')]
    #[Assert\Range(min: 0, max: 1000)]
    public ?int $position = null;
}
