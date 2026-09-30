<?php

namespace App\Security;

use App\Entity\User;
use App\Repository\UserRepository;
use Symfony\Component\Security\Core\Exception\UnsupportedUserException;
use Symfony\Component\Security\Core\Exception\UserNotFoundException;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\PasswordUpgraderInterface;
use Symfony\Component\Security\Core\User\UserInterface;
use Symfony\Component\Security\Core\User\UserProviderInterface;

/**
 * Loads an account by phone number, however it's typed: signing in with
 * "22 123 456" finds the account registered as "+216 22123456" (see
 * UserRepository::findOneByPhone).
 *
 * @implements UserProviderInterface<User>
 */
final class PhoneUserProvider implements UserProviderInterface, PasswordUpgraderInterface
{
    public function __construct(private readonly UserRepository $users)
    {
    }

    public function loadUserByIdentifier(string $identifier): UserInterface
    {
        $user = $this->users->findOneByPhone($identifier);
        if (null === $user) {
            $exception = new UserNotFoundException();
            $exception->setUserIdentifier($identifier);

            throw $exception;
        }

        return $user;
    }

    public function refreshUser(UserInterface $user): UserInterface
    {
        if (!$user instanceof User) {
            throw new UnsupportedUserException(sprintf('Instances of "%s" are not supported.', $user::class));
        }

        return $this->loadUserByIdentifier($user->getUserIdentifier());
    }

    /**
     * Rehashes a password with a newer algorithm on sign-in, as Doctrine's
     * entity provider did before this one replaced it.
     */
    public function upgradePassword(PasswordAuthenticatedUserInterface $user, string $newHashedPassword): void
    {
        $this->users->upgradePassword($user, $newHashedPassword);
    }

    public function supportsClass(string $class): bool
    {
        return User::class === $class || is_subclass_of($class, User::class);
    }
}
