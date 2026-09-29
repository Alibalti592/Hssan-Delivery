<?php

namespace App\Repository;

use App\Entity\BillProvider;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<BillProvider>
 */
class BillProviderRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, BillProvider::class);
    }

    /**
     * @return BillProvider[]
     */
    public function findAllOrdered(bool $activeOnly = false): array
    {
        $qb = $this->createQueryBuilder('bp')
            ->orderBy('bp.position', 'ASC')
            ->addOrderBy('bp.id', 'ASC');

        if ($activeOnly) {
            $qb->andWhere('bp.isActive = :true')->setParameter('true', true);
        }

        return $qb->getQuery()->getResult();
    }
}
