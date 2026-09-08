<?php

namespace App\Service;

use App\Entity\Delivery;
use App\Enum\DeliveryStatus;
use App\Dto\Order\CreateOrderRequest;
use App\Entity\Order;
use App\Entity\OrderItem;
use App\Entity\User;
use App\Enum\OrderStatus;
use App\Repository\OrderRepository;
use App\Repository\ProductRepository;
use App\Repository\RestaurantRepository;
use Doctrine\ORM\EntityManagerInterface;

final class OrderService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly OrderRepository $orderRepository,
        private readonly RestaurantRepository $restaurantRepository,
        private readonly ProductRepository $productRepository,
    ) {
    }

    public function createOrder(
        CreateOrderRequest $dto,
        User $user
    ): Order {
        $restaurant = $this->restaurantRepository->find($dto->restaurantId);

        if ($restaurant === null) {
            throw new \RuntimeException('Restaurant not found.');
        }

        if (!$restaurant->isAvailable()) {
            throw new \RuntimeException('Restaurant is currently unavailable.');
        }

        $order = new Order();

        $order->setUser($user);
        $order->setRestaurant($restaurant);
        $order->setNote($dto->note);
        $order->setDeliveryAddress($dto->deliveryAddress);
        $order->setStatus(OrderStatus::PENDING);

        $totalMillimes = 0;

        foreach ($dto->items as $itemDto) {
            $product = $this->productRepository->find($itemDto->productId);

            if ($product === null) {
                throw new \RuntimeException(
                    "Product {$itemDto->productId} not found."
                );
            }

            if ($product->getRestaurant()?->getId() !== $restaurant->getId()) {
                throw new \RuntimeException(
                    "Product {$itemDto->productId} does not belong to this restaurant."
                );
            }

            if (!$product->isAvailable()) {
                throw new \RuntimeException(
                    "Product {$itemDto->productId} is currently unavailable."
                );
            }

            $unitPrice = $product->getPrice();

            if ($unitPrice === null) {
                throw new \RuntimeException(
                    "Product {$itemDto->productId} has no price."
                );
            }

            $priceMillimes = $this->toMillimes($unitPrice);

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
            throw new \RuntimeException(
                'Order total must be greater than zero.'
            );
        }

        $order->setTotalAmount(
            $this->fromMillimes($totalMillimes)
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
    private function toMillimes(string $amount): int
    {
        [$whole, $decimal] = array_pad(
            explode('.', $amount, 2),
            2,
            ''
        );

        $decimal = str_pad($decimal, 3, '0');

        return ((int) $whole * 1000)
            + (int) substr($decimal, 0, 3);
    }

    private function fromMillimes(int $millimes): string
    {
        $whole = intdiv($millimes, 1000);
        $decimal = $millimes % 1000;

        return sprintf('%d.%03d', $whole, $decimal);
    }
}