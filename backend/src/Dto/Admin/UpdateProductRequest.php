<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Context\ExecutionContextInterface;

final class UpdateProductRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 255)]
    public ?string $name = null;

    #[Assert\Length(max: 5000)]
    public ?string $description = null;

    // Bounded to 7 integer digits to match the `price` column's
    // precision: 10, scale: 3 — an out-of-range value would otherwise pass
    // this check and fail at flush() with a raw DBAL exception instead of
    // a clean 422.
    // Required unless the product has options, in which case it's derived
    // from them (the lowest option price) — see validateOptions().
    #[Assert\Regex(
        pattern: '/^\d{1,7}(\.\d{1,3})?$/',
        message: 'Price must be a valid positive decimal with up to 3 decimal places.'
    )]
    public ?string $price = null;

    /**
     * @var ProductOptionRequest[]
     */
    #[Assert\Count(max: 10)]
    #[Assert\All([
        new Assert\Type(type: ProductOptionRequest::class),
    ])]
    #[Assert\Valid]
    public array $options = [];

    #[Assert\NotNull]
    #[Assert\Positive]
    public ?int $categoryId = null;

    public bool $isAvailable = true;

    #[Assert\Callback]
    public function validateOptions(ExecutionContextInterface $context): void
    {
        if ([] === $this->options && (null === $this->price || '' === $this->price)) {
            $context->buildViolation('Price is required when the product has no options.')
                ->atPath('price')
                ->addViolation();
        }

        $seen = [];

        foreach ($this->options as $index => $option) {
            if (!$option instanceof ProductOptionRequest || null === $option->name) {
                continue;
            }

            $key = mb_strtolower(trim($option->name));

            if (isset($seen[$key])) {
                $context->buildViolation('Each option name must be unique.')
                    ->atPath("options[$index].name")
                    ->addViolation();
            }

            $seen[$key] = true;
        }
    }
}