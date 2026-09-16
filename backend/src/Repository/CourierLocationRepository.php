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

    /**
     * Batches findOneByCourier() across a whole courier set — see
     * CourierLocationService::listForAdmin(), which otherwise issues one
     * query per courier on top of the one that lists them. Safe to key by
     * courier id with no dedup logic: each courier has at most one row
     * here by construction (see the class doc on CourierLocationService).
     *
     * @param User[] $couriers
     *
     * @return array<int, CourierLocation> keyed by courier id
     */
    public function findLatestByCouriers(array $couriers): array
    {
        if ([] === $couriers) {
            return [];
        }

        $locations = $this->createQueryBuilder('l')
            ->andWhere('l.courier IN (:couriers)')
            ->setParameter('couriers', $couriers)
            ->getQuery()
            ->getResult();

        $byCourierId = [];
        foreach ($locations as $location) {
            $byCourierId[$location->getCourier()->getId()] = $location;
        }

        return $byCourierId;
    }
}
