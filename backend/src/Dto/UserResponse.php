<?php

namespace App\Dto;

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
        public readonly string $email,
        public readonly string $name,
        public readonly string $phone,
        public readonly string $address,
        public readonly array $roles,
        public readonly bool $isVerified,
    ) {
    }

    public static function fromEntity(User $user): self
    {
        return new self(
            id: $user->getId(),
            email: $user->getEmail(),
            name: $user->getName(),
            phone: $user->getPhone(),
            address: $user->getAddress(),
            roles: $user->getRoles(),
            isVerified: $user->isVerified(),
        );
    }
}
