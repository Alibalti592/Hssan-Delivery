<?php

namespace App\Dto;

use App\Entity\Delivery;
use App\Entity\Order;

final class DeliveryResponse
{
    /**
     * @return array<string, mixed>
     */
    public static function fromEntity(Delivery $delivery): array
    {
        $order = $delivery->getOrder();

        return [
            'id' => $delivery->getId(),
            'orderId' => $order?->getId(),
            'status' => $delivery->getStatus()->value,
            'courierId' => $delivery->getCourier()?->getId(),
            'assignedAt' => $delivery->getAssignedAt()?->format(\DateTimeInterface::ATOM),
            'acceptedAt' => $delivery->getAcceptedAt()?->format(\DateTimeInterface::ATOM),
            'pickedUpAt' => $delivery->getPickedUpAt()?->format(\DateTimeInterface::ATOM),
            'deliveredAt' => $delivery->getDeliveredAt()?->format(\DateTimeInterface::ATOM),
            'createdAt' => $delivery->getCreatedAt()?->format(\DateTimeInterface::ATOM),
            'order' => null === $order ? null : self::orderSummary($order),
        ];
    }

    /**
     * Everything a courier needs to carry out the job: where to collect, where
     * to drop off, who to call, and what is in the bag.
     *
     * @return array<string, mixed>
     */
    private static function orderSummary(Order $order): array
    {
        $items = [];

        foreach ($order->getItems() as $item) {
            $items[] = [
                'productName' => $item->getProduct()?->getName(),
                'quantity' => $item->getQuantity(),
                'unitPrice' => $item->getUnitPrice(),
            ];
        }

        return [
            'id' => $order->getId(),
            'status' => $order->getStatus()->value,
            'restaurantName' => $order->getRestaurant()?->getName(),
            'customerName' => $order->getUser()?->getName(),
            'customerPhone' => $order->getUser()?->getPhone(),
            'deliveryAddress' => $order->getDeliveryAddress(),
            'note' => $order->getNote(),
            'deliveryFee' => $order->getDeliveryFee(),
            'totalAmount' => $order->getTotalAmount(),
            'items' => $items,
        ];
    }
}
