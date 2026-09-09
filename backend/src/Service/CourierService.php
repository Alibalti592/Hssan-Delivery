<?php

namespace App\Service;

use App\Entity\User;
use App\Repository\UserRepository;
use Doctrine\ORM\EntityManagerInterface;

final class CourierService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly UserRepository $userRepository,
    ) {
    }

    /**
     * @return User[]
     */
    public function list(): array
    {
        return $this->userRepository->findAllCouriers();
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
}
