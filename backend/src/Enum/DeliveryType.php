<?php

namespace App\Enum;

enum DeliveryType: string
{
    case RESTAURANT = 'RESTAURANT';
    case SUPERMARKET = 'SUPERMARKET';
    case PARCEL = 'PARCEL';
}