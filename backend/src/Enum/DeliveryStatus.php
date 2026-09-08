<?php

namespace App\Enum;

enum DeliveryStatus: string
{
    case PENDING = 'PENDING';
    case ASSIGNED = 'ASSIGNED';
    case ACCEPTED = 'ACCEPTED';
    case PICKED_UP = 'PICKED_UP';
    case ON_THE_WAY = 'ON_THE_WAY';
    case DELIVERED = 'DELIVERED';
    case CANCELLED = 'CANCELLED';
    case FAILED = 'FAILED';
}