<?php

namespace App\Enum;

enum OrderStatus: string
{
    case PENDING = 'PENDING';
    case PREPARING = 'PREPARING';
    case READY_FOR_PICKUP = 'READY_FOR_PICKUP';
    case ASSIGNED = 'ASSIGNED';
    case ACCEPTED = 'ACCEPTED';
    case PICKED_UP = 'PICKED_UP';
    case ON_THE_WAY = 'ON_THE_WAY';
    case DELIVERED = 'DELIVERED';
    case CANCELLED = 'CANCELLED';
    case FAILED = 'FAILED';
}