<?php

namespace App\Service;

use App\Dto\Admin\CreateDeliveryZoneRequest;
use App\Dto\Admin\UpdateDeliveryZoneRequest;
use App\Entity\DeliveryZone;
use App\Exception\ConflictException;
use App\Exception\InvalidOperationException;
use App\Repository\DeliveryZoneRepository;
use Doctrine\ORM\EntityManagerInterface;

final class DeliveryZoneService
{
    public const OUTSIDE_ZONES = 'Nous ne livrons pas encore à cette adresse.';

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
        $zone->setArea($dto->latitude, $dto->longitude, $dto->radiusKm);

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
        $zone->setArea($dto->latitude, $dto->longitude, $dto->radiusKm);

        $this->entityManager->flush();

        return $zone;
    }

    /**
     * The zone an address pin falls in: among the zones placed on the map
     * whose radius covers it, the one with the nearest center (where two
     * zones overlap). Null when none covers it.
     */
    public function locate(float $latitude, float $longitude): ?DeliveryZone
    {
        return $this->locateAmong($this->deliveryZoneRepository->findAllOrderedByName(), $latitude, $longitude);
    }

    /**
     * The zone that prices a delivery to an address. With a pin, it is the
     * zone covering the pin, whatever zone the client sent — the client
     * doesn't choose it. The zone they sent only counts for an address
     * without a pin, or while no zone is placed on the map yet.
     *
     * @throws InvalidOperationException when the pin is outside every placed
     *                                   zone, or the zone sent doesn't exist
     */
    public function resolve(?int $requestedId, ?float $latitude, ?float $longitude): ?DeliveryZone
    {
        if (null !== $latitude && null !== $longitude) {
            $zones = $this->deliveryZoneRepository->findAllOrderedByName();
            $located = $this->locateAmong($zones, $latitude, $longitude);

            if (null !== $located) {
                return $located;
            }

            foreach ($zones as $zone) {
                if ($zone->isPlaced()) {
                    throw new InvalidOperationException(self::OUTSIDE_ZONES);
                }
            }
        }

        if (null === $requestedId) {
            return null;
        }

        return $this->deliveryZoneRepository->find($requestedId)
            ?? throw new InvalidOperationException('Cette zone de livraison n\'existe plus. Choisissez-en une autre.');
    }

    /**
     * @param DeliveryZone[] $zones
     */
    private function locateAmong(array $zones, float $latitude, float $longitude): ?DeliveryZone
    {
        $best = null;
        $bestDistance = INF;

        foreach ($zones as $zone) {
            $distance = $zone->distanceKmFrom($latitude, $longitude);

            if (null !== $distance && $distance <= $zone->getRadiusKm() && $distance < $bestDistance) {
                $best = $zone;
                $bestDistance = $distance;
            }
        }

        return $best;
    }

    private function assertNameIsAvailable(string $name): void
    {
        if (null !== $this->deliveryZoneRepository->findOneBy(['name' => $name])) {
            throw new ConflictException('A delivery zone with this name already exists.');
        }
    }
}
