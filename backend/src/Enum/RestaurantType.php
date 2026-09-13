<?php

namespace App\Enum;

/**
 * A Restaurant row's vertical: the traditional restaurant/menu ordering
 * flow, or a grocery store selling everyday products through the same
 * Category/Product/Order infrastructure (see mobile HomeScreen's "Courses"
 * service). Deliberately not a copy of DeliveryType — a Restaurant row is
 * never a bill-payment or parcel entity, so only these two apply here.
 */
enum RestaurantType: string
{
    case RESTAURANT = 'RESTAURANT';
    case GROCERY = 'GROCERY';

    public function toDeliveryType(): DeliveryType
    {
        return match ($this) {
            self::RESTAURANT => DeliveryType::RESTAURANT,
            self::GROCERY => DeliveryType::GROCERY,
        };
    }
}
