<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

/**
 * One thing the customer can add to a product ("Harissa", "Fromage",
 * "Coca-Cola"...) and what it adds to the price, 0 for a free one — see
 * Product::$extraGroups.
 */
final class ProductExtraChoiceRequest
{
    #[Assert\NotBlank(normalizer: 'trim')]
    #[Assert\Length(max: 50)]
    public ?string $name = null;

    // Same bounds as CreateProductRequest::$price; "0" is fine.
    #[Assert\NotBlank]
    #[Assert\Regex(
        pattern: '/^\d{1,7}(\.\d{1,3})?$/',
        message: 'Price must be a valid positive decimal with up to 3 decimal places.'
    )]
    public ?string $price = '0';
}
