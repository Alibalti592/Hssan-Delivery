<?php

namespace App\Repository;

use App\Entity\RefreshToken;
use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<RefreshToken>
 */
class RefreshTokenRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, RefreshToken::class);
    }

    public function findOneByHash(string $tokenHash): ?RefreshToken
    {
        return $this->findOneBy(['tokenHash' => $tokenHash]);
    }

    /**
     * Signs the user out everywhere, except the device holding
     * [keepTokenHash] when given.
     */
    public function deleteAllForUser(User $user, ?string $keepTokenHash = null): void
    {
        $query = $this->createQueryBuilder('t')
            ->delete()
            ->andWhere('t.user = :user')
            ->setParameter('user', $user);
        if (null !== $keepTokenHash) {
            $query->andWhere('t.tokenHash != :keep')->setParameter('keep', $keepTokenHash);
        }

        $query->getQuery()->execute();
    }

    public function deleteExpiredForUser(User $user, \DateTimeImmutable $now): void
    {
        $this->createQueryBuilder('t')
            ->delete()
            ->andWhere('t.user = :user')
            ->andWhere('t.expiresAt <= :now')
            ->setParameter('user', $user)
            ->setParameter('now', $now)
            ->getQuery()
            ->execute();
    }
}
