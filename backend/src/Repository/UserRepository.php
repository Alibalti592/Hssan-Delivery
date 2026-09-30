<?php

namespace App\Repository;

use App\Entity\User;
use App\Pagination\PaginatedResult;
use App\Pagination\Paginator;
use App\Validator\PhoneFormat;
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
     * The account for a phone number however it's typed ("+216 22 123 456",
     * "22123456"...). Accounts created before numbers were normalized may
     * be stored with spaces or the country code, so when the exact value
     * isn't there this compares the last 8 digits of every stored number.
     */
    public function findOneByPhone(string $phone): ?User
    {
        $normalized = PhoneFormat::normalize($phone);

        $user = $this->findOneBy(['phone' => $normalized])
            ?? $this->findOneBy(['phone' => $phone]);
        if (null !== $user || 8 !== \strlen($normalized)) {
            return $user;
        }

        $id = $this->getEntityManager()->getConnection()->fetchOne(
            "SELECT id FROM \"user\" WHERE RIGHT(REGEXP_REPLACE(phone, '\\D', '', 'g'), 8) = :digits ORDER BY id LIMIT 1",
            ['digits' => $normalized],
        );

        return false === $id ? null : $this->find($id);
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
            ->orderBy('u.createdAt', 'DESC')
            // createdAt has only second precision — see DeliveryRepository
            // for why a tiebreaker is required for stable pagination.
            ->addOrderBy('u.id', 'DESC');

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
