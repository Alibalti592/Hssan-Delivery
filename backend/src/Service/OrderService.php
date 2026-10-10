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
use App\Repository\OrderRepository;
use App\Repository\ProductRepository;
use App\Repository\PromotionRepository;
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
        private readonly DeliveryZoneService $deliveryZoneService,
        private readonly DeliveryService $deliveryService,
        private readonly PromotionRepository $promotionRepository,
        private readonly PromotionPricing $promotionPricing,
    ) {
    }

    public function createOrder(
        CreateOrderRequest $dto,
        User $user,
    ): Order {
        $order = $this->priceOrder($dto, $user);

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
     * What createOrder would charge, without placing anything: the checkout
     * screen shows it as the client picks an address or types a code.
     */
    public function quoteOrder(CreateOrderRequest $dto, User $user): Order
    {
        return $this->priceOrder($dto, $user);
    }

    /**
     * Checks the cart and prices it, discount included, as an Order not yet
     * saved.
     */
    private function priceOrder(CreateOrderRequest $dto, User $user): Order
    {
        $restaurant = $this->restaurantRepository->find($dto->restaurantId);

        if (null === $restaurant) {
            throw new InvalidOperationException('Ce restaurant n\'existe plus.');
        }

        if (!$restaurant->isAvailable()) {
            throw new InvalidOperationException('Ce restaurant est fermé pour le moment.');
        }

        // The zone covering the drop-off pin, when there is one.
        $deliveryZone = $this->deliveryZoneService->resolve($dto->deliveryZoneId, $dto->deliveryLatitude, $dto->deliveryLongitude)
            ?? throw new InvalidOperationException('Choisissez la zone de livraison.');

        $order = new Order();

        $order->setUser($user);
        $order->setRestaurant($restaurant);
        $order->setNote($dto->note);
        $order->setDeliveryAddress($dto->deliveryAddress);
        $order->setDeliveryZone($deliveryZone);
        $order->setDeliveryLocation($dto->deliveryLatitude, $dto->deliveryLongitude);
        $order->setStatus(OrderStatus::PENDING);
        $order->setDeliveryType($restaurant->getType()->toDeliveryType());

        $totalMillimes = 0;
        // What a promotion may take off: not the fixed-price offers, which
        // are already discounted.
        $discountableMillimes = 0;

        foreach ($dto->items as $itemDto) {
            $product = $this->productRepository->find($itemDto->productId);

            if (null === $product) {
                throw new InvalidOperationException('Un article de votre panier n\'existe plus. Mettez votre panier à jour.');
            }

            if ($product->getRestaurant()?->getId() !== $restaurant->getId()) {
                throw new InvalidOperationException('Un article de votre panier ne vient pas de ce restaurant.');
            }

            if (!$product->isAvailable()) {
                throw new InvalidOperationException("« {$product->getName()} » n'est plus disponible.");
            }

            // A fixed-price offer's product sells only while the offer is
            // live: hidden, not started yet, or past its end date, it's off.
            $offer = $this->promotionRepository->findOneBy(['product' => $product]);

            if (null !== $offer && !$offer->isCurrentlyValid(new \DateTimeImmutable())) {
                throw new InvalidOperationException("L'offre « {$offer->getTitle()} » n'est plus disponible.");
            }

            $unitPrice = $product->getPrice();
            $optionName = null;

            if ([] !== $product->getOptions()) {
                if (null === $itemDto->option) {
                    throw new InvalidOperationException("Choisissez une taille pour « {$product->getName()} ».");
                }

                $option = $product->findOption($itemDto->option);

                if (null === $option) {
                    throw new InvalidOperationException("La taille « {$itemDto->option} » n'est plus proposée pour « {$product->getName()} ».");
                }

                $unitPrice = $option['price'];
                $optionName = $option['name'];
            } elseif (null !== $itemDto->option) {
                throw new InvalidOperationException("« {$product->getName()} » n'a pas de taille à choisir.");
            }

            if (null === $unitPrice) {
                throw new InvalidOperationException("« {$product->getName()} » n'a pas encore de prix.");
            }

            $priceMillimes = Money::toMillimes($unitPrice);

            $itemTotalMillimes =
                $priceMillimes * $itemDto->quantity;

            $totalMillimes += $itemTotalMillimes;

            if (null === $offer) {
                $discountableMillimes += $itemTotalMillimes;
            }

            $orderItem = new OrderItem();

            $orderItem->setProduct($product);
            $orderItem->setQuantity($itemDto->quantity);
            $orderItem->setUnitPrice($unitPrice);
            $orderItem->setOptionName($optionName);

            $order->addItem($orderItem);
        }

        if ($totalMillimes <= 0) {
            throw new InvalidOperationException('Votre commande est vide.');
        }

        $discount = $this->promotionPricing->bestDiscount(
            $restaurant,
            $discountableMillimes,
            $dto->promoCode,
            new \DateTimeImmutable(),
        );
        $discountMillimes = $discount['millimes'] ?? 0;

        if (null !== $discount) {
            $order->applyDiscount($discount['promotion'], Money::fromMillimes($discountMillimes));
        }

        $deliveryFeeMillimes = Money::toMillimes($deliveryZone->getFee());

        $order->setDeliveryFee(
            Money::fromMillimes($deliveryFeeMillimes)
        );
        $order->setTotalAmount(
            Money::fromMillimes($totalMillimes - $discountMillimes + $deliveryFeeMillimes)
        );

        return $order;
    }

    /**
     * A Colis order: no restaurant, no items — just carrying a package from
     * pickupAddress to deliveryAddress. Priced the same way as every other
     * service, off a DeliveryZone's flat fee: the zone of the sender's pickup
     * pin (the recipient's address is only typed), or of a drop-off pin from
     * an older app.
     */
    public function createParcelOrder(
        CreateParcelOrderRequest $dto,
        User $user,
    ): Order {
        [$latitude, $longitude] = null !== $dto->pickupLatitude
            ? [$dto->pickupLatitude, $dto->pickupLongitude]
            : [$dto->deliveryLatitude, $dto->deliveryLongitude];
        $deliveryZone = $this->deliveryZoneService->resolve($dto->deliveryZoneId, $latitude, $longitude)
            ?? throw new InvalidOperationException('Choisissez la zone de livraison.');

        $order = new Order();

        $order->setUser($user);
        $order->setPickupAddress($dto->pickupAddress);
        $order->setDeliveryAddress($dto->deliveryAddress);
        $order->setRecipientName($dto->recipientName);
        $order->setRecipientPhone($dto->recipientPhone);
        $order->setNote($dto->note);
        $order->setDeliveryZone($deliveryZone);
        $order->setDeliveryLocation($dto->deliveryLatitude, $dto->deliveryLongitude);
        $order->setStatus(OrderStatus::PENDING);
        $order->setDeliveryType(DeliveryType::PARCEL);
        $order->setPickupLocation($dto->pickupLatitude, $dto->pickupLongitude);

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
            ->addSelect('r', 'dz', 'd', 'c', 'bp')
            ->leftJoin('o.restaurant', 'r')
            ->leftJoin('o.billProvider', 'bp')
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
