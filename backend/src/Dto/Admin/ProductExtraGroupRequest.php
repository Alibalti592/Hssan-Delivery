<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Context\ExecutionContextInterface;

/**
 * A set of things the customer can add to a product: "Sauces",
 * "Suppléments", "Boisson"... — see Product::$extraGroups.
 */
final class ProductExtraGroupRequest
{
    #[Assert\NotBlank(normalizer: 'trim')]
    #[Assert\Length(max: 50)]
    public ?string $name = null;

    /** The customer must pick at least one. */
    #[Assert\Type('bool')]
    public bool $required = false;

    /** The customer may pick several; otherwise one at most. */
    #[Assert\Type('bool')]
    public bool $multiple = true;

    /**
     * @var ProductExtraChoiceRequest[]
     */
    #[Assert\Count(min: 1, max: 30, minMessage: 'Add at least one choice.')]
    #[Assert\All([
        new Assert\Type(type: ProductExtraChoiceRequest::class),
    ])]
    #[Assert\Valid]
    public array $choices = [];

    #[Assert\Callback]
    public function validateChoices(ExecutionContextInterface $context): void
    {
        $seen = [];

        foreach ($this->choices as $index => $choice) {
            if (!$choice instanceof ProductExtraChoiceRequest || null === $choice->name) {
                continue;
            }

            $key = mb_strtolower(trim($choice->name));

            if (isset($seen[$key])) {
                $context->buildViolation('Each choice name must be unique.')
                    ->atPath("choices[$index].name")
                    ->addViolation();
            }

            $seen[$key] = true;
        }
    }
}
