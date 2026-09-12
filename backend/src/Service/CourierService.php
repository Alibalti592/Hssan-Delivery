<?php

namespace App\Service;

use App\Entity\User;
use App\Pagination\PaginatedResult;
use App\Repository\UserRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class CourierService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly UserRepository $userRepository,
        private readonly UserPasswordHasherInterface $passwordHasher,
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
        $courier->setPassword(
            $this->passwordHasher->hashPassword($courier, $newPassword)
        );

        $this->entityManager->flush();

        return $courier;
    }
}
