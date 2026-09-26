<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

/**
 * One size/portion of a product ("M", "Familiale", "12 pièces"...) with its
 * own price — see Product::$options.
 */
final class ProductOptionRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(max: 50)]
    public ?string $name = null;

    // Same bounds as CreateProductRequest::$price.
    #[Assert\NotBlank]
    #[Assert\Regex(
        pattern: '/^\d{1,7}(\.\d{1,3})?$/',
        message: 'Price must be a valid positive decimal with up to 3 decimal places.'
    )]
    public ?string $price = null;
}
