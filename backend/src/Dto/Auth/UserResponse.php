<?php

namespace App\Dto\Auth;

use App\Entity\User;

/**
 * The user's own profile, as returned by /api/auth/*. Never expose the
 * User entity directly from a controller — build this DTO explicitly so
 * fields like the password hash can't leak by accident.
 */
final class UserResponse
{
    public function __construct(
        public readonly int $id,
        public readonly string $name,
        public readonly string $phone,
        public readonly array $roles,
        public readonly bool $isVerified,
    ) {
    }

    public static function fromEntity(User $user): self
    {
        return new self(
            id: $user->getId(),
            name: $user->getName(),
            phone: $user->getPhone(),
            roles: $user->getRoles(),
            isVerified: $user->isVerified(),
        );
    }
}
