<?php

namespace App\Repository;

use App\Entity\User;
use App\Pagination\PaginatedResult;
use App\Pagination\Paginator;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;
use Symfony\Component\Security\Core\Exception\UnsupportedUserException;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\PasswordUpgraderInterface;

/**
 * @extends ServiceEntityRepository<User>
 */
class UserRepository extends ServiceEntityRepository implements PasswordUpgraderInterface
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, User::class);
    }

    /**
     * Used to upgrade (rehash) the user's password automatically over time.
     */
    public function upgradePassword(PasswordAuthenticatedUserInterface $user, string $newHashedPassword): void
    {
        if (!$user instanceof User) {
            throw new UnsupportedUserException(sprintf('Instances of "%s" are not supported.', $user::class));
        }

        $user->setPassword($newHashedPassword);
        $this->getEntityManager()->persist($user);
        $this->getEntityManager()->flush();
    }

    /**
     * @return PaginatedResult<User>
     */
    public function paginateCouriers(int $page, int $limit): PaginatedResult
    {
        $ids = $this->findCourierIds();

        if ([] === $ids) {
            return new PaginatedResult([], 0, max(1, $page), max(1, min(Paginator::MAX_LIMIT, $limit)));
        }

        $qb = $this->createQueryBuilder('u')
            ->andWhere('u.id IN (:ids)')
            ->setParameter('ids', $ids)
            ->orderBy('u.createdAt', 'DESC');

        return Paginator::paginate($qb, $page, $limit);
    }

    public function countCouriers(): int
    {
        return count($this->findCourierIds());
    }

    /**
     * @return int[]
     */
    private function findCourierIds(): array
    {
        // "roles" is a Postgres `json` column, which has no native LIKE/
        // containment operator without an explicit cast — Doctrine's DQL
        // doesn't support that cast, so the role filter runs as a small raw
        // SQL query; callers hydrate/paginate/count from these ids instead.
        return array_map(
            'intval',
            $this->getEntityManager()->getConnection()->fetchFirstColumn(
                'SELECT id FROM "user" WHERE roles::text LIKE :role',
                ['role' => '%"ROLE_LIVREUR"%']
            )
        );
    }

    public function findCourier(int $id): ?User
    {
        $user = $this->find($id);

        if (null === $user || !in_array('ROLE_LIVREUR', $user->getRoles(), true)) {
            return null;
        }

        return $user;
    }

    //    public function findOneBySomeField($value): ?User
    //    {
    //        return $this->createQueryBuilder('u')
    //            ->andWhere('u.exampleField = :val')
    //            ->setParameter('val', $value)
    //            ->getQuery()
    //            ->getOneOrNullResult()
    //        ;
    //    }
}
