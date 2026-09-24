<?php

namespace App\Service;

use App\Dto\Admin\CreateCourierRequest;
use App\Dto\Auth\RegisterUserRequest;
use App\Entity\User;
use App\Exception\ConflictException;
use App\Exception\InvalidOperationException;
use App\Repository\UserRepository;
use Doctrine\DBAL\Exception\UniqueConstraintViolationException;
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

        try {
            $this->entityManager->flush();
        } catch (UniqueConstraintViolationException) {
            // The findOneBy check above is a fast path, not a lock — two
            // concurrent registrations with the same phone (a double-tap,
            // or a client retrying a slow request) can both pass it before
            // either commits. The DB's own unique index is what actually
            // prevents the duplicate; this turns the loser's raw DBAL
            // exception into the same clean 409 the fast path already
            // gives a sequential duplicate.
            throw new ConflictException(
                'An account with this phone number already exists.'
            );
        }

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

        // Unlike register() above, a courier account is NOT verified on
        // creation — being admin-*created* isn't the same as being
        // admin-*approved* (see User::$verifiedAt's docblock). An admin
        // still has to separately verify them (CourierService::verify)
        // before DeliveryService will let one be assigned a delivery.
        $courier->setRoles(['ROLE_LIVREUR']);

        $this->entityManager->persist($courier);

        try {
            $this->entityManager->flush();
        } catch (UniqueConstraintViolationException) {
            // See the identical comment in register() — same TOCTOU gap
            // between the check above and this flush.
            throw new ConflictException(
                'An account with this phone number already exists.'
            );
        }

        return $courier;
    }

    /**
     * Self-service password change for any authenticated user. Requires the
     * current password, so it's not a substitute for account recovery when
     * the user is locked out — see AdminCourierController::resetPassword()
     * for that case (couriers only; see its docblock for why).
     */
    public function changePassword(User $user, string $currentPassword, string $newPassword): void
    {
        if (!$this->passwordHasher->isPasswordValid($user, $currentPassword)) {
            throw new InvalidOperationException('Mot de passe actuel incorrect.');
        }

        $user->setPassword(
            $this->passwordHasher->hashPassword($user, $newPassword)
        );

        $this->entityManager->flush();
    }

    /**
     * Self-service toggle for a courier's own availability. Any account can
     * call it (no ROLE_LIVREUR check here — the route itself is gated), and
     * it's meaningless-but-harmless for a client to have it set.
     */
    public function setAvailability(User $user, bool $isAvailable): void
    {
        $user->setAvailable($isAvailable);

        $this->entityManager->flush();
    }
}