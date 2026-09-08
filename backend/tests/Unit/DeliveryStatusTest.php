<?php

namespace App\Tests\Unit;

use App\Enum\DeliveryStatus;
use App\Enum\OrderStatus;
use PHPUnit\Framework\TestCase;

final class DeliveryStatusTest extends TestCase
{
    /**
     * @dataProvider mapping
     */
    public function testToOrderStatus(DeliveryStatus $deliveryStatus, OrderStatus $expectedOrderStatus): void
    {
        self::assertSame($expectedOrderStatus, $deliveryStatus->toOrderStatus());
    }

    public static function mapping(): array
    {
        return [
            'pending' => [DeliveryStatus::PENDING, OrderStatus::PENDING],
            'assigned' => [DeliveryStatus::ASSIGNED, OrderStatus::CONFIRMED],
            'accepted' => [DeliveryStatus::ACCEPTED, OrderStatus::CONFIRMED],
            'picked up' => [DeliveryStatus::PICKED_UP, OrderStatus::READY_FOR_PICKUP],
            'on the way' => [DeliveryStatus::ON_THE_WAY, OrderStatus::READY_FOR_PICKUP],
            'delivered' => [DeliveryStatus::DELIVERED, OrderStatus::COMPLETED],
            'cancelled' => [DeliveryStatus::CANCELLED, OrderStatus::CANCELLED],
            'failed' => [DeliveryStatus::FAILED, OrderStatus::CANCELLED],
        ];
    }

    public function testEveryDeliveryStatusHasAMapping(): void
    {
        foreach (DeliveryStatus::cases() as $status) {
            self::assertInstanceOf(OrderStatus::class, $status->toOrderStatus());
        }
    }
}
