<?php

namespace App\Enum;

enum OrderStatus: string
{
    case PENDING = 'PENDING';
    case CONFIRMED = 'CONFIRMED';
    case PREPARING = 'PREPARING';
    case READY_FOR_PICKUP = 'READY_FOR_PICKUP';
    case COMPLETED = 'COMPLETED';
    case CANCELLED = 'CANCELLED';
}