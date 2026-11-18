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
     * Every customer's phones, for a notification to all of them (see
     * PushNotificationService::broadcast). Couriers and admins are left out:
     * an offer is no use to them.
     *
     * @return string[]
     */
    public function findClientTokenStrings(): array
    {
        return $this->getEntityManager()->getConnection()->fetchFirstColumn(
            'SELECT t.token'.self::CLIENT_TOKENS.' ORDER BY t.id'
        );
    }

    /** How many phones findClientTokenStrings() would reach. */
    public function countClientTokens(): int
    {
        return (int) $this->getEntityManager()->getConnection()->fetchOne(
            'SELECT COUNT(*)'.self::CLIENT_TOKENS
        );
    }

    private const CLIENT_TOKENS = ' FROM device_token t JOIN "user" u ON u.id = t.user_id'
        ." WHERE CAST(u.roles AS TEXT) LIKE '%ROLE_CLIENT%'";

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
