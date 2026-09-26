<?php

namespace App\Entity;

use App\Enum\DiscountType;
use App\Repository\PromotionRepository;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity(repositoryClass: PromotionRepository::class)]
#[ORM\HasLifecycleCallbacks]
class Promotion
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\Column(length: 255)]
    private ?string $title = null;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $description = null;

    #[ORM\Column(length: 255, nullable: true)]
    private ?string $imageFilename = null;

    #[ORM\Column(length: 20, enumType: DiscountType::class)]
    private DiscountType $discountType = DiscountType::PERCENTAGE;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 3)]
    private ?string $discountValue = null;

    #[ORM\Column(length: 50, nullable: true)]
    private ?string $promoCode = null;

    #[ORM\Column]
    private ?\DateTimeImmutable $startAt = null;

    /** Null = no end date: shown until the admin hides it (isActive). */
    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $endAt = null;

    #[ORM\Column]
    private bool $isActive = true;

    /**
     * Optional: a promotion can apply platform-wide (null) or be scoped to
     * one restaurant. Unidirectional — Restaurant doesn't need to know
     * about its promotions for anything built so far.
     */
    #[ORM\ManyToOne]
    #[ORM\JoinColumn(nullable: true)]
    private ?Restaurant $restaurant = null;

    /**
     * What a FIXED_PRICE offer includes, one line per item ("2 Sandwichs
     * Chawarma", "Frites dorées", ...). Empty for the other types.
     *
     * @var list<string>
     */
    #[ORM\Column(type: 'json')]
    private array $items = [];

    /**
     * The product a FIXED_PRICE offer is ordered as: created and kept in
     * sync by PromotionService (name = title, price = discountValue), in
     * the restaurant's "Offres" category. Going through a real product
     * means the cart, orders and deliveries need nothing offer-specific.
     * Null for the other types.
     */
    #[ORM\OneToOne]
    #[ORM\JoinColumn(nullable: true, onDelete: 'SET NULL')]
    private ?Product $product = null;

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

    public function getTitle(): ?string
    {
        return $this->title;
    }

    public function setTitle(string $title): static
    {
        $this->title = $title;

        return $this;
    }

    public function getDescription(): ?string
    {
        return $this->description;
    }

    public function setDescription(?string $description): static
    {
        $this->description = $description;

        return $this;
    }

    public function getImageFilename(): ?string
    {
        return $this->imageFilename;
    }

    public function setImageFilename(?string $imageFilename): static
    {
        $this->imageFilename = $imageFilename;

        return $this;
    }

    public function getDiscountType(): DiscountType
    {
        return $this->discountType;
    }

    public function setDiscountType(DiscountType $discountType): static
    {
        $this->discountType = $discountType;

        return $this;
    }

    public function getDiscountValue(): ?string
    {
        return $this->discountValue;
    }

    public function setDiscountValue(string $discountValue): static
    {
        $this->discountValue = $discountValue;

        return $this;
    }

    public function getPromoCode(): ?string
    {
        return $this->promoCode;
    }

    public function setPromoCode(?string $promoCode): static
    {
        $this->promoCode = $promoCode;

        return $this;
    }

    public function getStartAt(): ?\DateTimeImmutable
    {
        return $this->startAt;
    }

    public function setStartAt(\DateTimeImmutable $startAt): static
    {
        $this->startAt = $startAt;

        return $this;
    }

    public function getEndAt(): ?\DateTimeImmutable
    {
        return $this->endAt;
    }

    public function setEndAt(?\DateTimeImmutable $endAt): static
    {
        $this->endAt = $endAt;

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

    public function getRestaurant(): ?Restaurant
    {
        return $this->restaurant;
    }

    public function setRestaurant(?Restaurant $restaurant): static
    {
        $this->restaurant = $restaurant;

        return $this;
    }

    /**
     * @return list<string>
     */
    public function getItems(): array
    {
        return $this->items;
    }

    /**
     * @param list<string> $items
     */
    public function setItems(array $items): static
    {
        $this->items = $items;

        return $this;
    }

    public function getProduct(): ?Product
    {
        return $this->product;
    }

    public function setProduct(?Product $product): static
    {
        $this->product = $product;

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

    /**
     * Server-side source of truth for whether a promotion should be shown
     * to clients: active, and within its validity window right now.
     */
    public function isCurrentlyValid(\DateTimeImmutable $now): bool
    {
        return $this->isActive
            && $this->startAt <= $now
            && (null === $this->endAt || $this->endAt >= $now);
    }
}
