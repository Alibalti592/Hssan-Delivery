<?php

namespace App\Repository;

use App\Entity\Promotion;
use App\Enum\DiscountType;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\ORM\QueryBuilder;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Promotion>
 */
class PromotionRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Promotion::class);
    }

    /**
     * @return Promotion[]
     */
    public function findCurrentlyValid(\DateTimeImmutable $now): array
    {
        return $this->currentlyValid($now)
            ->orderBy('p.startAt', 'DESC')
            ->addOrderBy('p.id', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findOneCurrentlyValid(int $id, \DateTimeImmutable $now): ?Promotion
    {
        return $this->currentlyValid($now)
            ->andWhere('p.id = :id')
            ->setParameter('id', $id)
            ->getQuery()
            ->getOneOrNullResult();
    }

    /**
     * What clients may see: visible and inside its dates (as
     * Promotion::isCurrentlyValid), and nothing they couldn't act on -- a
     * restaurant's promotions go away while it's closed, and a fixed-price
     * offer needs its product on sale, or tapping "Commander" would only
     * end in an order the backend refuses.
     */
    private function currentlyValid(\DateTimeImmutable $now): QueryBuilder
    {
        return $this->createQueryBuilder('p')
            ->leftJoin('p.restaurant', 'r')
            ->leftJoin('p.product', 'offerProduct')
            ->andWhere('p.isActive = :true')
            ->andWhere('p.startAt <= :now')
            ->andWhere('p.endAt IS NULL OR p.endAt >= :now')
            ->andWhere('r.id IS NULL OR r.isAvailable = :true')
            ->andWhere('p.discountType != :offer OR offerProduct.isAvailable = :true')
            ->setParameter('true', true)
            ->setParameter('now', $now)
            ->setParameter('offer', DiscountType::FIXED_PRICE);
    }
}
