<?php

namespace App\Repository;

use App\Entity\Delivery;
use App\Entity\Order;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Pagination\PaginatedResult;
use App\Pagination\Paginator;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class DeliveryRepository extends ServiceEntityRepository
{
    private const ACTIVE_STATUSES = [
        DeliveryStatus::PENDING,
        DeliveryStatus::ASSIGNED,
        DeliveryStatus::ACCEPTED,
        DeliveryStatus::PICKED_UP,
        DeliveryStatus::ON_THE_WAY,
    ];

    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Delivery::class);
    }

    /**
     * The delivery a courier is currently working, if any — used by the
     * admin courier map to show "on delivery" status and link the marker to
     * the relevant delivery. A courier has at most one of these at a time.
     */
    public function findActiveForCourier(User $courier): ?Delivery
    {
        return $this->createQueryBuilder('d')
            ->andWhere('d.courier = :courier')
            ->andWhere('d.status IN (:statuses)')
            ->setParameter('courier', $courier)
            ->setParameter('statuses', self::ACTIVE_STATUSES)
            ->orderBy('d.createdAt', 'DESC')
            ->addOrderBy('d.id', 'DESC')
            ->setMaxResults(1)
            ->getQuery()
            ->getOneOrNullResult();
    }

    /**
     * Batches findActiveForCourier() across a whole courier set — see
     * CourierLocationService::listForAdmin(), which otherwise issues one
     * query per courier on top of the one that lists them.
     *
     * @param User[] $couriers
     *
     * @return array<int, Delivery> keyed by courier id
     */
    public function findActiveForCouriers(array $couriers): array
    {
        if ([] === $couriers) {
            return [];
        }

        $deliveries = $this->createQueryBuilder('d')
            ->andWhere('d.courier IN (:couriers)')
            ->andWhere('d.status IN (:statuses)')
            ->setParameter('couriers', $couriers)
            ->setParameter('statuses', self::ACTIVE_STATUSES)
            ->orderBy('d.createdAt', 'DESC')
            ->addOrderBy('d.id', 'DESC')
            ->getQuery()
            ->getResult();

        $byCourierId = [];
        foreach ($deliveries as $delivery) {
            // A courier has at most one active delivery at a time (see
            // findActiveForCourier's doc) — keep the first (most recent,
            // per the ORDER BY above) if that invariant is ever violated.
            $byCourierId[$delivery->getCourier()->getId()] ??= $delivery;
        }

        return $byCourierId;
    }

    /**
     * @return PaginatedResult<Delivery>
     */
    public function paginateByCourier(User $courier, int $page, int $limit): PaginatedResult
    {
        $qb = $this->createQueryBuilder('d')
            // DeliveryResponse::fromEntity/orderSummary touch all of these
            // per row — join them instead of leaving them to lazy-load one
            // query each. All to-one relations, safe alongside the
            // paginator's fetchJoinCollection: false (see Paginator).
            ->addSelect('c', 'o', 'r', 'u')
            ->leftJoin('d.courier', 'c')
            ->leftJoin('d.order', 'o')
            ->leftJoin('o.restaurant', 'r')
            ->leftJoin('o.user', 'u')
            ->andWhere('d.courier = :courier')
            ->setParameter('courier', $courier)
            ->orderBy('d.createdAt', 'DESC')
            // createdAt has only second precision, so rows created within
            // the same second tie — without this, LIMIT/OFFSET pagination
            // can return a row twice (or skip one) across separate page
            // requests, since a tie has no stable relative order otherwise.
            ->addOrderBy('d.id', 'DESC');

        $result = Paginator::paginate($qb, $page, $limit);
        $this->hydrateOrderItems($result->items);

        return $result;
    }

    /**
     * @return PaginatedResult<Delivery>
     */
    public function paginateAllOrderedByCreatedAtDesc(int $page, int $limit): PaginatedResult
    {
        $qb = $this->createQueryBuilder('d')
            ->addSelect('c', 'o', 'r', 'u')
            ->leftJoin('d.courier', 'c')
            ->leftJoin('d.order', 'o')
            ->leftJoin('o.restaurant', 'r')
            ->leftJoin('o.user', 'u')
            ->orderBy('d.createdAt', 'DESC')
            ->addOrderBy('d.id', 'DESC');

        $result = Paginator::paginate($qb, $page, $limit);
        $this->hydrateOrderItems($result->items);

        return $result;
    }

    /**
     * `order.items` is a to-many collection, so it can't be joined into the
     * paginated queries above without breaking the paginator's row count
     * (see OrderRepository::hydrateItems, which does the same thing for the
     * client/admin order lists) — batch-fetch it for the whole page here
     * instead, keyed by identity map, so each Delivery's already-loaded
     * Order gets its items (and each item's product) in one query.
     *
     * @param Delivery[] $deliveries
     */
    private function hydrateOrderItems(array $deliveries): void
    {
        $orders = array_filter(array_map(
            static fn (Delivery $delivery): ?Order => $delivery->getOrder(),
            $deliveries
        ));

        if ([] === $orders) {
            return;
        }

        $this->getEntityManager()->createQueryBuilder()
            ->select('o', 'oi', 'p')
            ->from(Order::class, 'o')
            ->leftJoin('o.items', 'oi')
            ->leftJoin('oi.product', 'p')
            ->where('o IN (:orders)')
            ->setParameter('orders', $orders)
            ->getQuery()
            ->getResult();
    }
}