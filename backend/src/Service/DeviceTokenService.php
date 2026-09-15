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
     *
     * Scoped to $user: a token another account currently owns is left
     * alone rather than deleted, so one signed-in user can't silently
     * unregister a stranger's device just by learning their token value
     * (e.g. from a shared device, a support screenshot, or a log line).
     */
    public function unregister(User $user, string $token): void
    {
        $deviceToken = $this->deviceTokenRepository->findOneBy(['token' => $token]);

        if (null === $deviceToken || $deviceToken->getUser()?->getId() !== $user->getId()) {
            return;
        }

        $this->entityManager->remove($deviceToken);
        $this->entityManager->flush();
    }
}
