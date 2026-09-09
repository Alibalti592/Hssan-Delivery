<?php

namespace App\Dto\Admin;

use App\Entity\Order;

final class OrderResponse
{
    public static function fromEntity(Order $order): array
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

        return [
            'id' => $order->getId(),
            'userId' => $order->getUser()?->getId(),
            'userName' => $order->getUser()?->getName(),
            'userPhone' => $order->getUser()?->getPhone(),
            'restaurantId' => $order->getRestaurant()?->getId(),
            'restaurantName' => $order->getRestaurant()?->getName(),
            'items' => $items,
            'note' => $order->getNote(),
            'deliveryAddress' => $order->getDeliveryAddress(),
            'deliveryZoneId' => $order->getDeliveryZone()?->getId(),
            'deliveryZoneName' => $order->getDeliveryZone()?->getName(),
            'deliveryFee' => $order->getDeliveryFee(),
            'totalAmount' => $order->getTotalAmount(),
            'status' => $order->getStatus()->value,
            'deliveryId' => $order->getDelivery()?->getId(),
            'createdAt' => $order->getCreatedAt()?->format(\DateTimeInterface::ATOM),
            'updatedAt' => $order->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
        ];
    }
}
