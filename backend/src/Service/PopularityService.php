<?php

namespace App\Service;

use App\Entity\Order;
use App\Entity\OrderItem;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Enum\OrderStatus;
use App\Enum\RestaurantType;
use Doctrine\ORM\EntityManagerInterface;

/**
 * What customers order most, for the home screen's "Les plus commandés" and
 * "Restaurants populaires": counted from delivered orders of the last
 * WINDOW_DAYS days, so it follows what people like now. A restaurant or a
 * dish needs MIN_ORDERS of them to count, so two orders never make a
 * "most ordered". Only what can be ordered right now is returned.
 */
final class PopularityService
{
    public const WINDOW_DAYS = 30;
    public const MIN_ORDERS = 3;

    /** Rows ranked and cached, more than any caller asks for. */
    private const RANKED = 50;

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly PopularityCache $cache,
    ) {
    }

    /**
     * @return list<array{restaurant: Restaurant, orderCount: int}>
     */
    public function popularRestaurants(\DateTimeImmutable $now, int $max): array
    {
        // The ranking is cached (PopularityCache); the restaurants are loaded
        // fresh, so one closed since is left out at once.
        $rows = $this->cache->get('popular.restaurants', fn () => $this->rankRestaurants($now));
        $restaurants = $this->byId(Restaurant::class, array_column($rows, 'id'));

        $popular = [];
        foreach ($rows as $row) {
            $restaurant = $restaurants[$row['id']] ?? null;
            if (null !== $restaurant && $restaurant->isAvailable() && count($popular) < $max) {
                $popular[] = ['restaurant' => $restaurant, 'orderCount' => (int) $row['orderCount']];
            }
        }

        return $popular;
    }

    /**
     * @return list<array{id: int, orderCount: int}>
     */
    private function rankRestaurants(\DateTimeImmutable $now): array
    {
        return $this->entityManager->createQueryBuilder()
            ->select('r.id AS id', 'COUNT(o.id) AS orderCount')
            ->from(Order::class, 'o')
            ->join('o.restaurant', 'r')
            ->andWhere('o.status = :completed')
            ->andWhere('o.createdAt >= :since')
            ->andWhere('r.isAvailable = true')
            ->andWhere('r.type = :type')
            ->groupBy('r.id')
            ->having('COUNT(o.id) >= :min')
            ->orderBy('orderCount', 'DESC')
            ->addOrderBy('r.name', 'ASC')
            ->setParameter('completed', OrderStatus::COMPLETED)
            ->setParameter('since', $this->since($now))
            ->setParameter('type', RestaurantType::RESTAURANT)
            ->setParameter('min', self::MIN_ORDERS)
            ->setMaxResults(self::RANKED)
            ->getQuery()
            ->getArrayResult();
    }

    /**
     * Dishes by how many delivered orders had them (two in one order count
     * once).
     *
     * @return list<array{product: Product, orderCount: int}>
     */
    public function popularDishes(\DateTimeImmutable $now, int $max): array
    {
        // As popularRestaurants: the ranking cached, the dishes fresh.
        $rows = $this->cache->get('popular.dishes', fn () => $this->rankDishes($now));
        $products = $this->dishesById(array_column($rows, 'id'));

        $popular = [];
        foreach ($rows as $row) {
            $product = $products[$row['id']] ?? null;
            if (null !== $product && $product->isAvailable() && true === $product->getRestaurant()?->isAvailable()
                && count($popular) < $max) {
                $popular[] = ['product' => $product, 'orderCount' => (int) $row['orderCount']];
            }
        }

        return $popular;
    }

    /**
     * @return list<array{id: int, orderCount: int}>
     */
    private function rankDishes(\DateTimeImmutable $now): array
    {
        return $this->entityManager->createQueryBuilder()
            ->select('p.id AS id', 'COUNT(DISTINCT o.id) AS orderCount')
            ->from(OrderItem::class, 'i')
            ->join('i.order', 'o')
            ->join('i.product', 'p')
            ->join('p.restaurant', 'r')
            ->andWhere('o.status = :completed')
            ->andWhere('o.createdAt >= :since')
            ->andWhere('p.isAvailable = true')
            ->andWhere('r.isAvailable = true')
            ->andWhere('r.type = :type')
            ->groupBy('p.id')
            ->having('COUNT(DISTINCT o.id) >= :min')
            ->orderBy('orderCount', 'DESC')
            ->addOrderBy('p.name', 'ASC')
            ->setParameter('completed', OrderStatus::COMPLETED)
            ->setParameter('since', $this->since($now))
            ->setParameter('type', RestaurantType::RESTAURANT)
            ->setParameter('min', self::MIN_ORDERS)
            ->setMaxResults(self::RANKED)
            ->getQuery()
            ->getArrayResult();
    }

    /**
     * @template T of object
     *
     * @param class-string<T> $class
     * @param list<int>       $ids
     *
     * @return array<int, T>
     */
    private function byId(string $class, array $ids): array
    {
        if ([] === $ids) {
            return [];
        }
        $found = [];
        foreach ($this->entityManager->getRepository($class)->findBy(['id' => $ids]) as $entity) {
            $found[$entity->getId()] = $entity;
        }

        return $found;
    }

    /**
     * With their restaurants, in one query: each is checked still open.
     *
     * @param list<int> $ids
     *
     * @return array<int, Product>
     */
    private function dishesById(array $ids): array
    {
        if ([] === $ids) {
            return [];
        }
        $found = [];
        $products = $this->entityManager->createQueryBuilder()
            ->select('p', 'r')
            ->from(Product::class, 'p')
            ->join('p.restaurant', 'r')
            ->andWhere('p.id IN (:ids)')
            ->setParameter('ids', $ids)
            ->getQuery()
            ->getResult();
        foreach ($products as $product) {
            $found[$product->getId()] = $product;
        }

        return $found;
    }

        private function since(\DateTimeImmutable $now): \DateTimeImmutable
    {
        return $now->modify(sprintf('-%d days', self::WINDOW_DAYS));
    }
}
