<?php

namespace App\Repository;

use App\Entity\Delivery;
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
     * @return PaginatedResult<Delivery>
     */
    public function paginateByCourier(User $courier, int $page, int $limit): PaginatedResult
    {
        $qb = $this->createQueryBuilder('d')
            ->andWhere('d.courier = :courier')
            ->setParameter('courier', $courier)
            ->orderBy('d.createdAt', 'DESC')
            // createdAt has only second precision, so rows created within
            // the same second tie — without this, LIMIT/OFFSET pagination
            // can return a row twice (or skip one) across separate page
            // requests, since a tie has no stable relative order otherwise.
            ->addOrderBy('d.id', 'DESC');

        return Paginator::paginate($qb, $page, $limit);
    }

    /**
     * @return PaginatedResult<Delivery>
     */
    public function paginateAllOrderedByCreatedAtDesc(int $page, int $limit): PaginatedResult
    {
        $qb = $this->createQueryBuilder('d')
            ->orderBy('d.createdAt', 'DESC')
            ->addOrderBy('d.id', 'DESC');

        return Paginator::paginate($qb, $page, $limit);
    }
}