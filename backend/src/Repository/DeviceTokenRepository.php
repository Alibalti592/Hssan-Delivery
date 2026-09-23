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

    /**
     * Bulk-removes device tokens FCM reported as invalid/unregistered (see
     * PushNotificationService::notifyUser) — called after every multicast
     * send so dead tokens don't accumulate and get retried on every future
     * notification. No ownership check needed: these token strings came
     * straight out of the send report for a message we just sent, not from
     * user input.
     *
     * @param string[] $tokens
     */
    public function deleteByTokens(array $tokens): void
    {
        if ([] === $tokens) {
            return;
        }

        $this->createQueryBuilder('t')
            ->delete()
            ->where('t.token IN (:tokens)')
            ->setParameter('tokens', $tokens)
            ->getQuery()
            ->execute();
    }
}
