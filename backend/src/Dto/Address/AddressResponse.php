<?php

namespace App\Dto\Address;

use App\Entity\Address;

final class AddressResponse
{
    public function __construct(
        public readonly int $id,
        public readonly string $label,
        public readonly string $addressLine,
        public readonly ?string $instructions,
        public readonly bool $isDefault,
        public readonly string $createdAt,
        public readonly string $updatedAt,
    ) {
    }

    public static function fromEntity(Address $address): self
    {
        return new self(
            id: $address->getId(),
            label: $address->getLabel(),
            addressLine: $address->getAddressLine(),
            instructions: $address->getInstructions(),
            isDefault: $address->isDefault(),
            createdAt: $address->getCreatedAt()->format(\DateTimeInterface::ATOM),
            updatedAt: $address->getUpdatedAt()->format(\DateTimeInterface::ATOM),
        );
    }
}
