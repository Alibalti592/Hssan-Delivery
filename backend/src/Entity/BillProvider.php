<?php

namespace App\Entity;

use App\Enum\BillProviderKind;
use App\Repository\BillProviderRepository;
use Doctrine\ORM\Mapping as ORM;

/**
 * A company whose bills (or money transfers) a courier can pay on a
 * client's behalf — the choices on the client's Factures screen. Managed
 * from the admin dashboard, logo included. Never deleted, only hidden
 * (isActive), since past orders keep pointing at it.
 */
#[ORM\Entity(repositoryClass: BillProviderRepository::class)]
#[ORM\HasLifecycleCallbacks]
class BillProvider
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\Column(length: 100, unique: true)]
    private ?string $name = null;

    #[ORM\Column(length: 20, enumType: BillProviderKind::class)]
    private BillProviderKind $kind = BillProviderKind::BILL;

    /**
     * Stored filename under public/uploads/bill-providers/.
     */
    #[ORM\Column(length: 255, nullable: true)]
    private ?string $logoFilename = null;

    #[ORM\Column]
    private bool $isActive = true;

    /**
     * Order on the client's screen, smallest first.
     */
    #[ORM\Column]
    private int $position = 0;

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

    public function getKind(): BillProviderKind
    {
        return $this->kind;
    }

    public function setKind(BillProviderKind $kind): static
    {
        $this->kind = $kind;

        return $this;
    }

    public function getLogoFilename(): ?string
    {
        return $this->logoFilename;
    }

    public function setLogoFilename(?string $logoFilename): static
    {
        $this->logoFilename = $logoFilename;

        return $this;
    }

    public function isActive(): bool
    {
        return $this->isActive;
    }

    public function setIsActive(bool $isActive): static
    {
        $this->isActive = $isActive;

        return $this;
    }

    public function getPosition(): int
    {
        return $this->position;
    }

    public function setPosition(int $position): static
    {
        $this->position = $position;

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
}
