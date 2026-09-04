<?php

namespace App\Entity;

enum DeliveryType: string
{
    case RESTAURANT = 'RESTAURANT';
    case SUPERMARKET = 'SUPERMARKET';
    case PARCEL = 'PARCEL';
}
