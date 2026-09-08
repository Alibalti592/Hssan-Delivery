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

    /**
     * The order status this delivery status keeps the parent order synced to.
     */
    public function toOrderStatus(): OrderStatus
    {
        return match ($this) {
            self::PENDING => OrderStatus::PENDING,
            self::ASSIGNED,
            self::ACCEPTED => OrderStatus::CONFIRMED,
            self::PICKED_UP,
            self::ON_THE_WAY => OrderStatus::READY_FOR_PICKUP,
            self::DELIVERED => OrderStatus::COMPLETED,
            self::CANCELLED,
            self::FAILED => OrderStatus::CANCELLED,
        };
    }
}
