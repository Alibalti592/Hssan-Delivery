<?php

namespace App\Service;

use App\Dto\Order\CreateOrderRequest;
use App\Entity\Delivery;
use App\Entity\Order;
use App\Entity\OrderItem;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\OrderStatus;
use App\Exception\InvalidOperationException;
use App\Repository\DeliveryZoneRepository;
use App\Repository\OrderRepository;
use App\Repository\ProductRepository;
use App\Repository\RestaurantRepository;
use App\Util\Money;
use Doctrine\ORM\EntityManagerInterface;

final class OrderService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly OrderRepository $orderRepository,
        private readonly RestaurantRepository $restaurantRepository,
        private readonly ProductRepository $productRepository,
        private readonly DeliveryZoneRepository $deliveryZoneRepository,
    ) {
    }

    public function createOrder(
        CreateOrderRequest $dto,
        User $user,
    ): Order {
        $restaurant = $this->restaurantRepository->find($dto->restaurantId);

        if (null === $restaurant) {
            throw new InvalidOperationException('Restaurant not found.');
        }

        if (!$restaurant->isAvailable()) {
            throw new InvalidOperationException('Restaurant is currently unavailable.');
        }

        $deliveryZone = $this->deliveryZoneRepository->find($dto->deliveryZoneId);

        if (null === $deliveryZone) {
            throw new InvalidOperationException('Delivery zone not found.');
        }

        $order = new Order();

        $order->setUser($user);
        $order->setRestaurant($restaurant);
        $order->setNote($dto->note);
        $order->setDeliveryAddress($dto->deliveryAddress);
        $order->setDeliveryZone($deliveryZone);
        $order->setStatus(OrderStatus::PENDING);

        $totalMillimes = 0;

        foreach ($dto->items as $itemDto) {
            $product = $this->productRepository->find($itemDto->productId);

            if (null === $product) {
                throw new InvalidOperationException("Product {$itemDto->productId} not found.");
            }

            if ($product->getRestaurant()?->getId() !== $restaurant->getId()) {
                throw new InvalidOperationException("Product {$itemDto->productId} does not belong to this restaurant.");
            }

            if (!$product->isAvailable()) {
                throw new InvalidOperationException("Product {$itemDto->productId} is currently unavailable.");
            }

            $unitPrice = $product->getPrice();

            if (null === $unitPrice) {
                throw new InvalidOperationException("Product {$itemDto->productId} has no price.");
            }

            $priceMillimes = Money::toMillimes($unitPrice);

            $itemTotalMillimes =
                $priceMillimes * $itemDto->quantity;

            $totalMillimes += $itemTotalMillimes;

            $orderItem = new OrderItem();

            $orderItem->setProduct($product);
            $orderItem->setQuantity($itemDto->quantity);
            $orderItem->setUnitPrice($unitPrice);

            $order->addItem($orderItem);
        }

        if ($totalMillimes <= 0) {
            throw new InvalidOperationException('Order total must be greater than zero.');
        }

        $deliveryFeeMillimes = Money::toMillimes($deliveryZone->getFee());

        $order->setDeliveryFee(
            Money::fromMillimes($deliveryFeeMillimes)
        );
        $order->setTotalAmount(
            Money::fromMillimes($totalMillimes + $deliveryFeeMillimes)
        );
        $delivery = new Delivery();

        $delivery->setOrder($order);
        $delivery->setStatus(DeliveryStatus::PENDING);

        $order->setDelivery($delivery);

        $this->entityManager->persist($delivery);

        $this->entityManager->persist($order);
        $this->entityManager->flush();

        return $order;
    }

    public function getUserOrders(User $user): array
    {
        return $this->orderRepository->findBy(
            ['user' => $user],
            ['createdAt' => 'DESC']
        );
    }

    public function getUserOrder(int $orderId, User $user): ?Order
    {
        return $this->orderRepository->findOneBy([
            'id' => $orderId,
            'user' => $user,
        ]);
    }
}
