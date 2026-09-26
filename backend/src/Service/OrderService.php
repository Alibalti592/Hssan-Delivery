<?php

namespace App\Service;

use App\Dto\Order\CreateOrderRequest;
use App\Dto\Order\CreateParcelOrderRequest;
use App\Entity\Delivery;
use App\Entity\Order;
use App\Entity\OrderItem;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\DeliveryType;
use App\Enum\OrderStatus;
use App\Exception\InvalidOperationException;
use App\Pagination\PaginatedResult;
use App\Pagination\Paginator;
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
        private readonly DeliveryService $deliveryService,
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
        $order->setDeliveryType($restaurant->getType()->toDeliveryType());

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
            $optionName = null;

            if ([] !== $product->getOptions()) {
                if (null === $itemDto->option) {
                    throw new InvalidOperationException("Choose an option for product {$itemDto->productId}.");
                }

                $option = $product->findOption($itemDto->option);

                if (null === $option) {
                    throw new InvalidOperationException("Option \"{$itemDto->option}\" is not available for product {$itemDto->productId}.");
                }

                $unitPrice = $option['price'];
                $optionName = $option['name'];
            } elseif (null !== $itemDto->option) {
                throw new InvalidOperationException("Product {$itemDto->productId} has no options.");
            }

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
            $orderItem->setOptionName($optionName);

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

    /**
     * A Colis order: no restaurant, no items — just carrying a package from
     * pickupAddress to deliveryAddress. Priced the same way as every other
     * service, off the chosen DeliveryZone's flat fee.
     */
    public function createParcelOrder(
        CreateParcelOrderRequest $dto,
        User $user,
    ): Order {
        $deliveryZone = $this->deliveryZoneRepository->find($dto->deliveryZoneId);

        if (null === $deliveryZone) {
            throw new InvalidOperationException('Delivery zone not found.');
        }

        $order = new Order();

        $order->setUser($user);
        $order->setPickupAddress($dto->pickupAddress);
        $order->setDeliveryAddress($dto->deliveryAddress);
        $order->setRecipientName($dto->recipientName);
        $order->setRecipientPhone($dto->recipientPhone);
        $order->setNote($dto->note);
        $order->setDeliveryZone($deliveryZone);
        $order->setStatus(OrderStatus::PENDING);
        $order->setDeliveryType(DeliveryType::PARCEL);

        $deliveryFeeMillimes = Money::toMillimes($deliveryZone->getFee());

        $order->setDeliveryFee(
            Money::fromMillimes($deliveryFeeMillimes)
        );
        $order->setTotalAmount(
            Money::fromMillimes($deliveryFeeMillimes)
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

    /**
     * @return PaginatedResult<Order>
     */
    public function getUserOrders(User $user, int $page, int $limit): PaginatedResult
    {
        $qb = $this->orderRepository->createQueryBuilder('o')
            // OrderResponse::fromEntity touches all of these per row — join
            // them instead of leaving them to lazy-load one query each. All
            // to-one relations, safe alongside fetchJoinCollection: false.
            ->addSelect('r', 'dz', 'd', 'c')
            ->leftJoin('o.restaurant', 'r')
            ->leftJoin('o.deliveryZone', 'dz')
            ->leftJoin('o.delivery', 'd')
            ->leftJoin('d.courier', 'c')
            ->andWhere('o.user = :user')
            ->setParameter('user', $user)
            ->orderBy('o.createdAt', 'DESC')
            // createdAt has only second precision — see DeliveryRepository
            // for why a tiebreaker is required for stable pagination.
            ->addOrderBy('o.id', 'DESC');

        $result = Paginator::paginate($qb, $page, $limit);
        $this->orderRepository->hydrateItems($result->items);

        return $result;
    }

    public function getUserOrder(int $orderId, User $user): ?Order
    {
        return $this->orderRepository->findOneBy([
            'id' => $orderId,
            'user' => $user,
        ]);
    }

    /**
     * Cancelling an order cancels its (1:1) delivery, which is the source of
     * truth for whether cancellation is still allowed — a client can back
     * out while it's unclaimed or just assigned, but not once a courier has
     * actually accepted it. See DeliveryService::cancelDelivery.
     */
    public function cancelOrder(Order $order): Order
    {
        $delivery = $order->getDelivery();

        if (null === $delivery) {
            // Data-integrity invariant: every order is created with a delivery.
            throw new \LogicException('Order must be associated with a delivery.');
        }

        $this->deliveryService->cancelDelivery($delivery);

        return $order;
    }
}
