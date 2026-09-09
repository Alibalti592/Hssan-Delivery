<?php

namespace App\Service;

use App\Dto\Admin\CreateDeliveryZoneRequest;
use App\Dto\Admin\UpdateDeliveryZoneRequest;
use App\Entity\DeliveryZone;
use App\Repository\DeliveryZoneRepository;
use Doctrine\ORM\EntityManagerInterface;

final class DeliveryZoneService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly DeliveryZoneRepository $deliveryZoneRepository,
    ) {
    }

    public function create(CreateDeliveryZoneRequest $dto): DeliveryZone
    {
        $name = trim((string) $dto->name);

        $this->assertNameIsAvailable($name);

        $zone = new DeliveryZone();

        $zone->setName($name);
        $zone->setFee($dto->fee);

        $this->entityManager->persist($zone);
        $this->entityManager->flush();

        return $zone;
    }

    /**
     * @return DeliveryZone[]
     */
    public function list(): array
    {
        return $this->deliveryZoneRepository->findAllOrderedByName();
    }

    public function get(int $id): ?DeliveryZone
    {
        return $this->deliveryZoneRepository->find($id);
    }

    public function update(
        DeliveryZone $zone,
        UpdateDeliveryZoneRequest $dto,
    ): DeliveryZone {
        $name = trim((string) $dto->name);

        if ($name !== $zone->getName()) {
            $this->assertNameIsAvailable($name);
        }

        $zone->setName($name);
        $zone->setFee($dto->fee);

        $this->entityManager->flush();

        return $zone;
    }

    private function assertNameIsAvailable(string $name): void
    {
        if (null !== $this->deliveryZoneRepository->findOneBy(['name' => $name])) {
            throw new \RuntimeException('A delivery zone with this name already exists.');
        }
    }
}
