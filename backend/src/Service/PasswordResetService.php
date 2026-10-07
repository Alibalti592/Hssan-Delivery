<?php

namespace App\Service;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * An admin setting someone's password for them: there is no email or SMS
 * channel to verify identity through, so a client who forgot theirs asks
 * support on WhatsApp, and the admin sets a new one and sends it back.
 */
final class PasswordResetService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly UserPasswordHasherInterface $passwordHasher,
        private readonly RefreshTokenService $refreshTokens,
    ) {
    }

    public function reset(User $user, string $newPassword): User
    {
        $user->setPassword(
            $this->passwordHasher->hashPassword($user, $newPassword)
        );

        $this->entityManager->flush();

        // Whoever was signed in with the old password is signed out.
        $this->refreshTokens->revokeAll($user);

        return $user;
    }
}
