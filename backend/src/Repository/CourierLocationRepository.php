<?php

namespace App\Repository;

use App\Entity\CourierLocation;
use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<CourierLocation>
 */
class CourierLocationRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, CourierLocation::class);
    }

    public function findOneByCourier(User $courier): ?CourierLocation
    {
        return $this->findOneBy(['courier' => $courier]);
    }
}
