<?php

namespace App\Entity;

use App\Repository\AddressRepository;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity(repositoryClass: AddressRepository::class)]
#[ORM\HasLifecycleCallbacks]
class Address
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(nullable: false)]
    private ?User $user = null;

    #[ORM\Column(length: 255)]
    private ?string $label = null;

    #[ORM\Column(type: 'text')]
    private ?string $addressLine = null;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $instructions = null;

    #[ORM\Column]
    private bool $isDefault = false;

    /**
     * The zone that prices deliveries here, so picking this address fills
     * in the fee too. Null for addresses saved before it existed, or once
     * the zone is gone.
     */
    #[ORM\ManyToOne]
    #[ORM\JoinColumn(nullable: true, onDelete: 'SET NULL')]
    private ?DeliveryZone $deliveryZone = null;

    /**
     * Where the client put the pin on the map — what the courier navigates
     * to. Null when they only typed the address.
     */
    #[ORM\Column(nullable: true)]
    private ?float $latitude = null;

    #[ORM\Column(nullable: true)]
    private ?float $longitude = null;

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

    public function getUser(): ?User
    {
        return $this->user;
    }

    public function setUser(?User $user): static
    {
        $this->user = $user;

        return $this;
    }

    public function getLabel(): ?string
    {
        return $this->label;
    }

    public function setLabel(string $label): static
    {
        $this->label = $label;

        return $this;
    }

    public function getAddressLine(): ?string
    {
        return $this->addressLine;
    }

    public function setAddressLine(string $addressLine): static
    {
        $this->addressLine = $addressLine;

        return $this;
    }

    public function getInstructions(): ?string
    {
        return $this->instructions;
    }

    public function setInstructions(?string $instructions): static
    {
        $this->instructions = $instructions;

        return $this;
    }

    public function isDefault(): bool
    {
        return $this->isDefault;
    }

    public function setDefault(bool $isDefault): static
    {
        $this->isDefault = $isDefault;

        return $this;
    }

    public function getCreatedAt(): ?\DateTimeImmutable
    {
        return $this->createdAt;
    }

    public function getUpdatedAt(): ?\DateTimeImmutable
    {
        return $this->updatedAt;
    }

    public function getDeliveryZone(): ?DeliveryZone
    {
        return $this->deliveryZone;
    }

    public function setDeliveryZone(?DeliveryZone $deliveryZone): static
    {
        $this->deliveryZone = $deliveryZone;

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

    public function setLocation(?float $latitude, ?float $longitude): static
    {
        $this->latitude = $latitude;
        $this->longitude = $longitude;

        return $this;
    }
}
