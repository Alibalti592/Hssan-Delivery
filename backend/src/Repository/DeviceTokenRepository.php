<?php

namespace App\Repository;

use App\Entity\DeviceToken;
use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<DeviceToken>
 */
class DeviceTokenRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, DeviceToken::class);
    }

    /**
     * @return string[]
     */
    public function findTokenStringsForUser(User $user): array
    {
        return array_map(
            static fn (DeviceToken $t) => $t->getToken(),
            $this->findBy(['user' => $user])
        );
    }
}
