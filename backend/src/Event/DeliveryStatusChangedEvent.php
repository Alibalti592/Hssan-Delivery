<?php

namespace App\Event;

use App\Entity\Delivery;
use App\Enum\DeliveryStatus;

/**
 * Dispatched once a delivery status transition has committed (see
 * DeliveryService::transitionWithLock). Never dispatched for a transition
 * that throws or rolls back.
 */
final class DeliveryStatusChangedEvent
{
    public function __construct(
        public readonly Delivery $delivery,
        public readonly DeliveryStatus $previousStatus,
    ) {
    }
}
