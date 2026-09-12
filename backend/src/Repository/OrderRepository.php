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
            ->orderBy('o.createdAt', 'DESC');

        return Paginator::paginate($qb, $page, $limit);
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
