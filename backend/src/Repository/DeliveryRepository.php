<?php

namespace App\Repository;

use App\Entity\Delivery;
use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class DeliveryRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Delivery::class);
    }

    /**
     * @return Delivery[]
     */
    public function findByCourier(User $courier): array
    {
        return $this->createQueryBuilder('d')
            ->andWhere('d.courier = :courier')
            ->setParameter('courier', $courier)
            ->orderBy('d.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * @return Delivery[]
     */
    public function findAllOrderedByCreatedAtDesc(): array
    {
        return $this->findBy([], ['createdAt' => 'DESC']);
    }
}