<?php

namespace App\Repository;

use App\Entity\Delivery;
use App\Entity\User;
use App\Pagination\PaginatedResult;
use App\Pagination\Paginator;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class DeliveryRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Delivery::class);
    }

    /**
     * @return PaginatedResult<Delivery>
     */
    public function paginateByCourier(User $courier, int $page, int $limit): PaginatedResult
    {
        $qb = $this->createQueryBuilder('d')
            ->andWhere('d.courier = :courier')
            ->setParameter('courier', $courier)
            ->orderBy('d.createdAt', 'DESC');

        return Paginator::paginate($qb, $page, $limit);
    }

    /**
     * @return PaginatedResult<Delivery>
     */
    public function paginateAllOrderedByCreatedAtDesc(int $page, int $limit): PaginatedResult
    {
        $qb = $this->createQueryBuilder('d')
            ->orderBy('d.createdAt', 'DESC');

        return Paginator::paginate($qb, $page, $limit);
    }
}