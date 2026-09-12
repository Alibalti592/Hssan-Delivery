<?php

namespace App\Service;

use App\Entity\DeviceToken;
use App\Entity\User;
use App\Repository\DeviceTokenRepository;
use Doctrine\ORM\EntityManagerInterface;

final class DeviceTokenService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly DeviceTokenRepository $deviceTokenRepository,
    ) {
    }

    /**
     * Re-registering a token already owned by someone else reassigns it to
     * $user — the same device switched accounts, so its old owner should
     * stop getting pushes meant for it.
     */
    public function register(User $user, string $token, ?string $platform): void
    {
        $deviceToken = $this->deviceTokenRepository->findOneBy(['token' => $token])
            ?? new DeviceToken();

        $deviceToken->setUser($user);
        $deviceToken->setToken($token);
        $deviceToken->setPlatform($platform);

        $this->entityManager->persist($deviceToken);
        $this->entityManager->flush();
    }

    /**
     * Called on sign-out so a shared/reset device stops receiving pushes
     * for an account no longer signed in on it.
     */
    public function unregister(string $token): void
    {
        $deviceToken = $this->deviceTokenRepository->findOneBy(['token' => $token]);

        if (null === $deviceToken) {
            return;
        }

        $this->entityManager->remove($deviceToken);
        $this->entityManager->flush();
    }
}
