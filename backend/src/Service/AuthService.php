<?php

namespace App\Service;

use App\Dto\Admin\CreateCourierRequest;
use App\Dto\Auth\RegisterUserRequest;
use App\Entity\User;
use App\Exception\ConflictException;
use App\Repository\UserRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class AuthService
{
    public function __construct(
        private readonly UserPasswordHasherInterface $passwordHasher,
        private readonly EntityManagerInterface $entityManager,
        private readonly UserRepository $userRepository,
    ) {
    }

    public function register(RegisterUserRequest $dto): User
    {
        if (
            $this->userRepository->findOneBy([
                'phone' => $dto->phone,
            ]) !== null
        ) {
            throw new ConflictException(
                'An account with this phone number already exists.'
            );
        }

        $user = new User();

        $user->setName($dto->name);
        $user->setPhone($dto->phone);
        $user->setPassword(
            $this->passwordHasher->hashPassword(
                $user,
                $dto->password
            )
        );

        // Public registration creates CLIENT accounts only.
        $user->setRoles(['ROLE_CLIENT']);
        $user->setVerifiedAt(new \DateTimeImmutable());

        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    public function createCourier(
        CreateCourierRequest $dto
    ): User {
        if (
            $this->userRepository->findOneBy([
                'phone' => $dto->phone,
            ]) !== null
        ) {
            throw new ConflictException(
                'An account with this phone number already exists.'
            );
        }

        $courier = new User();

        $courier->setName($dto->name);
        $courier->setPhone($dto->phone);
        $courier->setPassword(
            $this->passwordHasher->hashPassword(
                $courier,
                $dto->password
            )
        );

        // Courier accounts are created and approved by an admin.
        $courier->setRoles(['ROLE_LIVREUR']);
        $courier->setVerifiedAt(new \DateTimeImmutable());

        $this->entityManager->persist($courier);
        $this->entityManager->flush();

        return $courier;
    }
}