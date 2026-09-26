<?php

namespace App\Enum;

enum DiscountType: string
{
    case PERCENTAGE = 'PERCENTAGE';
    case FIXED_AMOUNT = 'FIXED_AMOUNT';
    // A bundle sold at a set price ("2 sandwiches + frites — 11 DT"): the
    // promotion's discountValue is that price, and it is ordered through
    // its generated product (see Promotion::$product).
    case FIXED_PRICE = 'FIXED_PRICE';
}
