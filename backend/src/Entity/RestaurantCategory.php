<?php

namespace App\Entity;

use App\Repository\RestaurantCategoryRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;

/**
 * What a restaurant serves, for browsing: "Pizza", "Sucré", "Cuisine
 * Tunisienne"... A restaurant can have several, and the client filters the
 * restaurant list by one. Managed from the admin dashboard.
 *
 * Not to be confused with Category, a section of one restaurant's menu.
 */
#[ORM\Entity(repositoryClass: RestaurantCategoryRepository::class)]
#[ORM\HasLifecycleCallbacks]
class RestaurantCategory
{
    /**
     * The icons the app can draw for a category (see the mobile app's
     * CategoryIcon) when it has no image of its own.
     */
    public const ICONS = [
        'restaurant',
        'fast_food',
        'burger',
        'pizza',
        'kebab',
        'grill',
        'bowl',
        'soup',
        'pasta',
        'fish',
        'tapas',
        'croissant',
        'breakfast',
        'leaf',
        'cake',
        'ice_cream',
        'coffee',
        'drink',
        'basket',
    ];

    public const DEFAULT_ICON = 'restaurant';

    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\Column(length: 100, unique: true)]
    private ?string $name = null;

    /**
     * One of self::ICONS.
     */
    #[ORM\Column(length: 40)]
    private string $icon = self::DEFAULT_ICON;

    /**
     * Stored filename under public/uploads/restaurant-categories/; shown
     * instead of the icon when set.
     */
    #[ORM\Column(length: 255, nullable: true)]
    private ?string $imageFilename = null;

    /**
     * Order in the app's category row, smallest first.
     */
    #[ORM\Column]
    private int $position = 0;

    /**
     * @var Collection<int, Restaurant>
     */
    #[ORM\ManyToMany(targetEntity: Restaurant::class, mappedBy: 'restaurantCategories', fetch: 'EXTRA_LAZY')]
    private Collection $restaurants;

    #[ORM\Column]
    private ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column]
    private ?\DateTimeImmutable $updatedAt = null;

    public function __construct()
    {
        $this->restaurants = new ArrayCollection();
    }

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

    public function getIcon(): string
    {
        return $this->icon;
    }

    public function setIcon(string $icon): static
    {
        $this->icon = $icon;

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

    public function getPosition(): int
    {
        return $this->position;
    }

    public function setPosition(int $position): static
    {
        $this->position = $position;

        return $this;
    }

    /**
     * @return Collection<int, Restaurant>
     */
    public function getRestaurants(): Collection
    {
        return $this->restaurants;
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
