<?php

namespace App\Repository;

use App\Entity\DeliveryZone;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class DeliveryZoneRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, DeliveryZone::class);
    }

    /**
     * @return DeliveryZone[]
     */
    public function findAllOrderedByName(): array
    {
        return $this->createQueryBuilder('z')
            ->orderBy('z.name', 'ASC')
            ->getQuery()
            ->getResult();
    }
}
