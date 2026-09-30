<?php

namespace App\Service;

use App\Entity\RefreshToken;
use App\Entity\User;
use App\Repository\RefreshTokenRepository;
use Doctrine\ORM\EntityManagerInterface;
use Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface;

/**
 * Long-lived sign-in for the mobile app. Login hands out a refresh token
 * next to the one-hour JWT; POST /api/auth/refresh trades it for a new JWT
 * and a new refresh token (the old one stops working, so a stolen token
 * is only good until the real app next refreshes).
 *
 * Signing out, changing the password, an admin resetting a courier's
 * password or deactivating them all revoke the tokens.
 */
final class RefreshTokenService
{
    /** How long the app stays signed in without being opened. */
    public const TTL = '+30 days';

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly RefreshTokenRepository $refreshTokens,
        private readonly JWTTokenManagerInterface $jwtManager,
    ) {
    }

    /**
     * A new refresh token for [user], returned in plain text once: only its
     * hash is kept.
     */
    public function issue(User $user): string
    {
        $now = new \DateTimeImmutable();
        $this->refreshTokens->deleteExpiredForUser($user, $now);

        $plain = bin2hex(random_bytes(32));
        $this->entityManager->persist(
            new RefreshToken($user, self::hash($plain), $now->modify(self::TTL))
        );
        $this->entityManager->flush();

        return $plain;
    }

    /**
     * Trades a refresh token for a new JWT and a new refresh token, or null
     * when it's unknown, expired, or its account was deactivated.
     *
     * @return array{token: string, refreshToken: string}|null
     */
    public function refresh(string $plain): ?array
    {
        $stored = $this->refreshTokens->findOneByHash(self::hash($plain));
        if (null === $stored) {
            return null;
        }

        $user = $stored->getUser();
        $this->entityManager->remove($stored);
        $this->entityManager->flush();

        if ($stored->isExpired() || !$user->isActive()) {
            return null;
        }

        return [
            'token' => $this->jwtManager->create($user),
            'refreshToken' => $this->issue($user),
        ];
    }

    /** Signs one device out. Unknown tokens are ignored. */
    public function revoke(string $plain): void
    {
        $stored = $this->refreshTokens->findOneByHash(self::hash($plain));
        if (null !== $stored) {
            $this->entityManager->remove($stored);
            $this->entityManager->flush();
        }
    }

    /**
     * Signs [user] out on every device, except the one holding [keep] (the
     * device that just changed the password stays signed in).
     */
    public function revokeAll(User $user, ?string $keep = null): void
    {
        $this->refreshTokens->deleteAllForUser($user, null === $keep ? null : self::hash($keep));
    }

    private static function hash(string $plain): string
    {
        return hash('sha256', $plain);
    }
}
