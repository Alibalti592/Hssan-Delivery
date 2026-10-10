<?php

namespace App\Entity;

use App\Repository\DeliveryZoneRepository;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity(repositoryClass: DeliveryZoneRepository::class)]
#[ORM\HasLifecycleCallbacks]
class DeliveryZone
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\Column(length: 255, unique: true)]
    private ?string $name = null;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 3)]
    private ?string $fee = null;

    /**
     * The zone on the map: a center the admin placed and the radius it
     * covers. Null until placed; an address pin inside it gets this zone
     * automatically (DeliveryZoneService::locate).
     */
    #[ORM\Column(nullable: true)]
    private ?float $latitude = null;

    #[ORM\Column(nullable: true)]
    private ?float $longitude = null;

    #[ORM\Column(nullable: true)]
    private ?float $radiusKm = null;

    #[ORM\Column]
    private ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column]
    private ?\DateTimeImmutable $updatedAt = null;

    #[ORM\PrePersist]
    public function onPrePersist(): void
    {
        $now = new \DateTimeImmutable();

        $this->createdAt = $now;
        $this->updatedAt = $now;
    }

    #[ORM\PreUpdate]
    public function onPreUpdate(): void
    {
        $this->updatedAt = new \DateTimeImmutable();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getName(): ?string
    {
        return $this->name;
    }

    public function setName(string $name): static
    {
        $this->name = $name;

        return $this;
    }

    public function getFee(): ?string
    {
        return $this->fee;
    }

    public function setFee(string $fee): static
    {
        $this->fee = $fee;

        return $this;
    }

    public function getLatitude(): ?float
    {
        return $this->latitude;
    }

    public function getLongitude(): ?float
    {
        return $this->longitude;
    }

    public function getRadiusKm(): ?float
    {
        return $this->radiusKm;
    }

    /**
     * Places the zone on the map, or takes it off (all three null).
     */
    public function setArea(?float $latitude, ?float $longitude, ?float $radiusKm): static
    {
        $this->latitude = $latitude;
        $this->longitude = $longitude;
        $this->radiusKm = $radiusKm;

        return $this;
    }

    public function isPlaced(): bool
    {
        return null !== $this->latitude && null !== $this->longitude && null !== $this->radiusKm;
    }

    /**
     * Straight-line distance from the zone's center, in km (haversine), or
     * null for a zone not placed on the map.
     */
    public function distanceKmFrom(float $latitude, float $longitude): ?float
    {
        if (!$this->isPlaced()) {
            return null;
        }

        $toRad = static fn (float $deg): float => $deg * M_PI / 180;
        $dLat = $toRad($latitude - $this->latitude);
        $dLng = $toRad($longitude - $this->longitude);
        $a = sin($dLat / 2) ** 2
            + cos($toRad($this->latitude)) * cos($toRad($latitude)) * sin($dLng / 2) ** 2;

        return 6371.0 * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    public function getCreatedAt(): ?\DateTimeImmutable
    {
        return $this->createdAt;
    }

    public function getUpdatedAt(): ?\DateTimeImmutable
    {
        return $this->updatedAt;
    }
}
