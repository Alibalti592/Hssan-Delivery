<?php

namespace App\Service;

use App\Dto\Address\CreateAddressRequest;
use App\Dto\Address\UpdateAddressRequest;
use App\Entity\Address;
use App\Entity\User;
use App\Repository\AddressRepository;
use Doctrine\ORM\EntityManagerInterface;

final class AddressService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly AddressRepository $addressRepository,
    ) {
    }

    public function create(User $user, CreateAddressRequest $dto): Address
    {
        $address = new Address();

        $address->setUser($user);
        $address->setLabel(trim($dto->label));
        $address->setAddressLine(trim($dto->addressLine));
        $address->setInstructions($dto->instructions);
        $address->setDefault($dto->isDefault);

        $this->entityManager->persist($address);
        $this->entityManager->flush();

        if ($dto->isDefault) {
            $this->addressRepository->clearDefaultForUser($user, $address);
        }

        return $address;
    }

    /**
     * @return Address[]
     */
    public function listForUser(User $user): array
    {
        return $this->addressRepository->findAllForUser($user);
    }

    public function get(int $id, User $user): ?Address
    {
        return $this->addressRepository->findOwnedBy($id, $user);
    }

    public function update(Address $address, UpdateAddressRequest $dto): Address
    {
        $address->setLabel(trim($dto->label));
        $address->setAddressLine(trim($dto->addressLine));
        $address->setInstructions($dto->instructions);
        $address->setDefault($dto->isDefault);

        $this->entityManager->flush();

        if ($dto->isDefault) {
            $this->addressRepository->clearDefaultForUser($address->getUser(), $address);
        }

        return $address;
    }

    public function delete(Address $address): void
    {
        $this->entityManager->remove($address);
        $this->entityManager->flush();
    }
}
