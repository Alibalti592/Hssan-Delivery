<?php

namespace App\Service;

use App\Entity\User;
use App\Pagination\PaginatedResult;
use App\Repository\UserRepository;
use Doctrine\ORM\EntityManagerInterface;

final class CourierService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly UserRepository $userRepository,
        private readonly RefreshTokenService $refreshTokens,
        private readonly PasswordResetService $passwordReset,
    ) {
    }

    /**
     * @return PaginatedResult<User>
     */
    public function list(int $page, int $limit): PaginatedResult
    {
        return $this->userRepository->paginateCouriers($page, $limit);
    }

    public function get(int $id): ?User
    {
        return $this->userRepository->findCourier($id);
    }

    public function setActive(User $courier, bool $isActive): User
    {
        $courier->setActive($isActive);

        $this->entityManager->flush();

        // A deactivated courier's app stops being able to renew its session.
        if (!$isActive) {
            $this->refreshTokens->revokeAll($courier);
        }

        return $courier;
    }

    /**
     * Admin approval step for a courier account — separate from creating
     * it (AuthService::createCourier leaves a new courier unverified). See
     * User::$verifiedAt's docblock: DeliveryService won't let an unverified
     * courier be assigned a delivery. Idempotent: verifying an
     * already-verified courier just leaves their original verifiedAt in
     * place.
     */
    public function verify(User $courier): User
    {
        if (!$courier->isVerified()) {
            $courier->setVerifiedAt(new \DateTimeImmutable());
            $this->entityManager->flush();
        }

        return $courier;
    }

    /**
     * Admin-initiated password reset, for a courier locked out of their
     * account. Mirrors AuthService::createCourier(): the admin picks the new
     * password and relays it to the courier out-of-band (phone call, in
     * person, etc.), the same way the initial password is handled at
     * account creation.
     */
    public function resetPassword(User $courier, string $newPassword): User
    {
        return $this->passwordReset->reset($courier, $newPassword);
    }
}
