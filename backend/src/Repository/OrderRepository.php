<?php

namespace App\Repository;

use App\Entity\Order;
use App\Enum\OrderStatus;
use App\Pagination\PaginatedResult;
use App\Pagination\Paginator;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class OrderRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Order::class);
    }

    /**
     * @return PaginatedResult<Order>
     */
    public function paginateAllOrderedByCreatedAtDesc(int $page, int $limit): PaginatedResult
    {
        $qb = $this->createQueryBuilder('o')
            // Admin\OrderResponse::fromEntity touches all of these per row —
            // join them here instead of leaving them to lazy-load one query
            // each. All to-one relations, so this is safe alongside the
            // paginator's fetchJoinCollection: false (see Paginator).
            ->addSelect('u', 'r', 'dz', 'd', 'c')
            ->leftJoin('o.user', 'u')
            ->leftJoin('o.restaurant', 'r')
            ->leftJoin('o.deliveryZone', 'dz')
            ->leftJoin('o.delivery', 'd')
            ->leftJoin('d.courier', 'c')
            ->orderBy('o.createdAt', 'DESC')
            // createdAt has only second precision — see DeliveryRepository
            // for why a tiebreaker is required for stable pagination.
            ->addOrderBy('o.id', 'DESC');

        $result = Paginator::paginate($qb, $page, $limit);
        $this->hydrateItems($result->items);

        return $result;
    }

    /**
     * `items` is a to-many collection, so it can't be joined into the
     * paginated query above without breaking the paginator's row count
     * (Doctrine's collection-fetch-join semantics assume no LIMIT/OFFSET).
     * Batch-fetching it here for the whole page, keyed by identity map, is
     * the standard fix: this SELECT hydrates each already-loaded Order's
     * `items` (and each item's `product`) in one query instead of one query
     * per order plus one per item.
     *
     * @param Order[] $orders
     */
    public function hydrateItems(array $orders): void
    {
        if ([] === $orders) {
            return;
        }

        $this->createQueryBuilder('o')
            ->select('o', 'oi', 'p')
            ->leftJoin('o.items', 'oi')
            ->leftJoin('oi.product', 'p')
            ->where('o IN (:orders)')
            ->setParameter('orders', $orders)
            ->getQuery()
            ->getResult();
    }

    /**
     * Orders that haven't reached a terminal state yet. Used for the admin
     * dashboard's "Active Orders" count — a dedicated COUNT query rather
     * than paging through every order client-side, since that count needs
     * to stay accurate regardless of how many orders exist in total.
     */
    public function countActive(): int
    {
        return (int) $this->createQueryBuilder('o')
            ->select('COUNT(o.id)')
            ->andWhere('o.status NOT IN (:terminal)')
            ->setParameter('terminal', [OrderStatus::COMPLETED, OrderStatus::CANCELLED])
            ->getQuery()
            ->getSingleScalarResult();
    }
}
