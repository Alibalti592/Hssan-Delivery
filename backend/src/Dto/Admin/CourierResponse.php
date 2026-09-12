<?php

namespace App\Dto\Admin;

use App\Entity\User;

final class CourierResponse
{
    public static function fromEntity(User $courier): array
    {
        return [
            'id' => $courier->getId(),
            'name' => $courier->getName(),
            'phone' => $courier->getPhone(),
            'roles' => $courier->getRoles(),
            'verified' => $courier->isVerified(),
            'isActive' => $courier->isActive(),
            'createdAt' => $courier->getCreatedAt()?->format(\DateTimeInterface::ATOM),
            'updatedAt' => $courier->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
        ];
    }
}
