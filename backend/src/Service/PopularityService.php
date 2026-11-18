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

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
    ) {
    }

    /**
     * @return list<array{restaurant: Restaurant, orderCount: int}>
     */
    public function popularRestaurants(\DateTimeImmutable $now, int $max): array
    {
        $rows = $this->entityManager->createQueryBuilder()
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
            ->setMaxResults($max)
            ->getQuery()
            ->getResult();

        $restaurants = $this->byId(Restaurant::class, array_column($rows, 'id'));

        return array_map(
            static fn (array $row) => ['restaurant' => $restaurants[$row['id']], 'orderCount' => (int) $row['orderCount']],
            $rows
        );
    }

    /**
     * Dishes by how many delivered orders had them (two in one order count
     * once).
     *
     * @return list<array{product: Product, orderCount: int}>
     */
    public function popularDishes(\DateTimeImmutable $now, int $max): array
    {
        $rows = $this->entityManager->createQueryBuilder()
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
            ->setMaxResults($max)
            ->getQuery()
            ->getResult();

        $products = $this->byId(Product::class, array_column($rows, 'id'));

        return array_map(
            static fn (array $row) => ['product' => $products[$row['id']], 'orderCount' => (int) $row['orderCount']],
            $rows
        );
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

    private function since(\DateTimeImmutable $now): \DateTimeImmutable
    {
        return $now->modify(sprintf('-%d days', self::WINDOW_DAYS));
    }
}
