<?php

namespace App\Dto\Order;

use App\Entity\Order;

final class OrderResponse
{
    public function __construct(
        public readonly int $id,
        public readonly int $restaurantId,
        public readonly array $items,
        public readonly ?string $note,
        public readonly string $deliveryAddress,
        public readonly int $deliveryZoneId,
        public readonly string $deliveryZoneName,
        public readonly string $deliveryFee,
        public readonly string $totalAmount,
        public readonly string $status,
        public readonly string $createdAt,
    ) {
    }

    public static function fromEntity(Order $order): self
    {
        $items = [];

        foreach ($order->getItems() as $item) {
            $items[] = [
                'id' => $item->getId(),
                'productId' => $item->getProduct()?->getId(),
                'productName' => $item->getProduct()?->getName(),
                'quantity' => $item->getQuantity(),
                'unitPrice' => $item->getUnitPrice(),
            ];
        }

        return new self(
            id: $order->getId(),
            restaurantId: $order->getRestaurant()->getId(),
            items: $items,
            note: $order->getNote(),
            deliveryAddress: $order->getDeliveryAddress(),
            deliveryZoneId: $order->getDeliveryZone()->getId(),
            deliveryZoneName: $order->getDeliveryZone()->getName(),
            deliveryFee: $order->getDeliveryFee(),
            totalAmount: $order->getTotalAmount(),
            status: $order->getStatus()->value,
            createdAt: $order->getCreatedAt()->format(\DateTimeInterface::ATOM),
        );
    }
}