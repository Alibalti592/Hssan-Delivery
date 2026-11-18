<?php

namespace App\Repository;

use App\Entity\PushCampaign;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<PushCampaign>
 */
class PushCampaignRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, PushCampaign::class);
    }

    /**
     * @return list<PushCampaign>
     */
    public function latest(int $max): array
    {
        return $this->createQueryBuilder('c')
            ->orderBy('c.sentAt', 'DESC')
            ->addOrderBy('c.id', 'DESC')
            ->setMaxResults($max)
            ->getQuery()
            ->getResult();
    }

    /** Sent since [since]: the guard against a double send. */
    public function countSince(\DateTimeImmutable $since): int
    {
        return (int) $this->createQueryBuilder('c')
            ->select('COUNT(c.id)')
            ->andWhere('c.sentAt >= :since')
            ->setParameter('since', $since)
            ->getQuery()
            ->getSingleScalarResult();
    }
}
