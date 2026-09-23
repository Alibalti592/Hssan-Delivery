<?php

namespace App\Event;

use App\Entity\Delivery;
use App\Entity\User;
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
        /**
         * The courier assigned to the delivery before this transition, if
         * any — distinct from $delivery->getCourier(), which already
         * reflects the *new* state by the time this event fires. Needed to
         * tell a reassignment (see DeliveryService::reassignCourier) apart
         * from a fresh assignment: on a reassignment this is the courier
         * who just lost the delivery and needs to be told, not the one who
         * gained it.
         */
        public readonly ?User $previousCourier = null,
    ) {
    }
}
