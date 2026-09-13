<?php

namespace App\Entity;

use App\Repository\CourierLocationRepository;
use Doctrine\ORM\Mapping as ORM;

/**
 * A courier's last known GPS position — not a location history/trail, just
 * the single most recent point (upserted on every update, see
 * CourierLocationService). There is no continuous background tracking
 * behind this: the mobile app only reports while it's open and the courier
 * has an active delivery, so treat updatedAt as "how stale is this" rather
 * than assuming real-time movement.
 */
#[ORM\Entity(repositoryClass: CourierLocationRepository::class)]
#[ORM\HasLifecycleCallbacks]
class CourierLocation
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\OneToOne]
    #[ORM\JoinColumn(nullable: false, unique: true)]
    private ?User $courier = null;

    #[ORM\Column(type: 'float')]
    private ?float $latitude = null;

    #[ORM\Column(type: 'float')]
    private ?float $longitude = null;

    #[ORM\Column]
    private ?\DateTimeImmutable $updatedAt = null;

    #[ORM\PreUpdate]
    #[ORM\PrePersist]
    public function touch(): void
    {
        $this->updatedAt = new \DateTimeImmutable();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getCourier(): ?User
    {
        return $this->courier;
    }

    public function setCourier(User $courier): static
    {
        $this->courier = $courier;

        return $this;
    }

    public function getLatitude(): ?float
    {
        return $this->latitude;
    }

    public function setLatitude(float $latitude): static
    {
        $this->latitude = $latitude;

        return $this;
    }

    public function getLongitude(): ?float
    {
        return $this->longitude;
    }

    public function setLongitude(float $longitude): static
    {
        $this->longitude = $longitude;

        return $this;
    }

    public function getUpdatedAt(): ?\DateTimeImmutable
    {
        return $this->updatedAt;
    }
}
