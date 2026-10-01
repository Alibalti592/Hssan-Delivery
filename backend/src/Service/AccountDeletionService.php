<?php

namespace App\Service;

use App\Entity\Address;
use App\Entity\CourierLocation;
use App\Entity\DeviceToken;
use App\Entity\Order;
use App\Entity\User;
use App\Enum\OrderStatus;
use App\Exception\ConflictException;
use App\Exception\InvalidOperationException;
use App\Repository\DeliveryRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * "Supprimer mon compte", as the app stores require. The person's data
 * goes — name, phone number, saved addresses, devices, sessions, last
 * position — while their past orders stay (the business's own records),
 * attached to an account that no longer says who it was and can't sign
 * in. The phone number becomes free to register again.
 */
final class AccountDeletionService
{
    public const DELETED_NAME = 'Compte supprimé';

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly UserPasswordHasherInterface $passwordHasher,
        private readonly DeliveryRepository $deliveries,
        private readonly RefreshTokenService $refreshTokens,
    ) {
    }

    public function delete(User $user, string $password): void
    {
        if (\in_array('ROLE_ADMIN', $user->getRoles(), true)) {
            throw new InvalidOperationException("Un compte administrateur ne se supprime pas depuis l'application.");
        }
        if (!$this->passwordHasher->isPasswordValid($user, $password)) {
            throw new InvalidOperationException('Mot de passe incorrect.');
        }
        if ($this->hasOrderInProgress($user) || null !== $this->deliveries->findActiveForCourier($user)) {
            throw new ConflictException('Vous avez une commande en cours. Vous pourrez supprimer votre compte une fois qu\'elle sera terminée.');
        }

        foreach ([Address::class => 'user', DeviceToken::class => 'user', CourierLocation::class => 'courier'] as $entity => $owner) {
            $this->entityManager->createQuery("DELETE FROM $entity e WHERE e.$owner = :user")
                ->setParameter('user', $user)
                ->execute();
        }
        $this->refreshTokens->revokeAll($user);

        $user->setName(self::DELETED_NAME);
        // Unique, can't be typed as a phone number, and frees the real one.
        $user->setPhone(sprintf('supprime-%d-%s', $user->getId(), bin2hex(random_bytes(4))));
        $user->setPassword($this->passwordHasher->hashPassword($user, bin2hex(random_bytes(32))));
        $user->setActive(false);
        $user->setAvailable(false);

        $this->entityManager->flush();
    }

    private function hasOrderInProgress(User $user): bool
    {
        return (int) $this->entityManager->createQueryBuilder()
            ->select('COUNT(o.id)')
            ->from(Order::class, 'o')
            ->andWhere('o.user = :user')
            ->andWhere('o.status NOT IN (:done)')
            ->setParameter('user', $user)
            ->setParameter('done', [OrderStatus::COMPLETED, OrderStatus::CANCELLED])
            ->getQuery()
            ->getSingleScalarResult() > 0;
    }
}
