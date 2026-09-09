<?php

namespace App\Repository;

use App\Entity\Address;
use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

class AddressRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Address::class);
    }

    /**
     * @return Address[]
     */
    public function findAllForUser(User $user): array
    {
        return $this->createQueryBuilder('a')
            ->andWhere('a.user = :user')
            ->setParameter('user', $user)
            ->orderBy('a.isDefault', 'DESC')
            ->addOrderBy('a.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function findOwnedBy(int $id, User $user): ?Address
    {
        return $this->findOneBy([
            'id' => $id,
            'user' => $user,
        ]);
    }

    /**
     * Clears the default flag on every other address belonging to $user,
     * so isDefault stays a single-address invariant per user.
     */
    public function clearDefaultForUser(User $user, ?Address $except = null): void
    {
        $qb = $this->createQueryBuilder('a')
            ->update()
            ->set('a.isDefault', ':false')
            ->andWhere('a.user = :user')
            ->setParameter('false', false)
            ->setParameter('user', $user);

        if (null !== $except) {
            $qb->andWhere('a.id != :exceptId')
                ->setParameter('exceptId', $except->getId());
        }

        $qb->getQuery()->execute();
    }
}
