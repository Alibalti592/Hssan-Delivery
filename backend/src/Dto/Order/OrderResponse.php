<?php

namespace App\Dto\Order;

use App\Entity\Order;

final class OrderResponse
{
    public function __construct(
        public readonly int $id,
        public readonly ?int $restaurantId,
        public readonly ?string $restaurantName,
        public readonly array $items,
        public readonly ?string $note,
        public readonly ?string $pickupAddress,
        public readonly string $deliveryAddress,
        public readonly ?string $recipientName,
        public readonly ?string $recipientPhone,
        public readonly int $deliveryZoneId,
        public readonly string $deliveryZoneName,
        public readonly string $deliveryFee,
        public readonly string $totalAmount,
        public readonly string $status,
        public readonly string $deliveryType,
        public readonly string $createdAt,
        public readonly ?int $deliveryId,
        public readonly ?string $deliveryStatus,
        public readonly ?string $courierName,
        public readonly ?string $courierPhone,
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

        $delivery = $order->getDelivery();
        $courier = $delivery?->getCourier();

        return new self(
            id: $order->getId(),
            restaurantId: $order->getRestaurant()?->getId(),
            restaurantName: $order->getRestaurant()?->getName(),
            items: $items,
            note: $order->getNote(),
            pickupAddress: $order->getPickupAddress(),
            deliveryAddress: $order->getDeliveryAddress(),
            recipientName: $order->getRecipientName(),
            recipientPhone: $order->getRecipientPhone(),
            deliveryZoneId: $order->getDeliveryZone()->getId(),
            deliveryZoneName: $order->getDeliveryZone()->getName(),
            deliveryFee: $order->getDeliveryFee(),
            totalAmount: $order->getTotalAmount(),
            status: $order->getStatus()->value,
            deliveryType: $order->getDeliveryType()->value,
            createdAt: $order->getCreatedAt()->format(\DateTimeInterface::ATOM),
            deliveryId: $delivery?->getId(),
            deliveryStatus: $delivery?->getStatus()->value,
            // Only surfaced once a courier is actually assigned — a client
            // has no one to call before then, and no other way to reach
            // whoever the platform picks besides this.
            courierName: $courier?->getName(),
            courierPhone: $courier?->getPhone(),
        );
    }
}