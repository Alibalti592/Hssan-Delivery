<?php

namespace App\Repository;

use App\Entity\RestaurantCategory;
use App\Enum\RestaurantType;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<RestaurantCategory>
 */
class RestaurantCategoryRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, RestaurantCategory::class);
    }

    /**
     * @return RestaurantCategory[]
     */
    public function findAllOrdered(): array
    {
        return $this->createQueryBuilder('rc')
            ->orderBy('rc.position', 'ASC')
            ->addOrderBy('rc.id', 'ASC')
            ->getQuery()
            ->getResult();
    }

    /**
     * The categories a client can filter by: those of at least one open
     * restaurant (or grocery store, depending on $type). One with nothing
     * to show behind it is left out.
     *
     * @return RestaurantCategory[]
     */
    public function findInUse(RestaurantType $type): array
    {
        return $this->createQueryBuilder('rc')
            ->andWhere('EXISTS (
                SELECT 1 FROM App\Entity\Restaurant r
                WHERE rc MEMBER OF r.restaurantCategories
                AND r.isAvailable = :available
                AND r.type = :type
            )')
            ->setParameter('available', true)
            ->setParameter('type', $type)
            ->orderBy('rc.position', 'ASC')
            ->addOrderBy('rc.id', 'ASC')
            ->getQuery()
            ->getResult();
    }

    /**
     * How many restaurants each category has, by category id.
     *
     * @return array<int, int>
     */
    public function countRestaurantsByCategory(): array
    {
        $rows = $this->createQueryBuilder('rc')
            ->select('rc.id AS id', 'COUNT(r.id) AS total')
            ->leftJoin('rc.restaurants', 'r')
            ->groupBy('rc.id')
            ->getQuery()
            ->getArrayResult();

        $counts = [];

        foreach ($rows as $row) {
            $counts[(int) $row['id']] = (int) $row['total'];
        }

        return $counts;
    }
}
