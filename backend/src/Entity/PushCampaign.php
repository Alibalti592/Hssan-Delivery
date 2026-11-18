<?php

namespace App\Entity;

use App\Repository\PushCampaignRepository;
use Doctrine\ORM\Mapping as ORM;

/**
 * A notification the admin sent to every customer ("⚡ FLASH HOUR : -35% !"),
 * kept so the admin page shows what went out, when, and to how many phones.
 */
#[ORM\Entity(repositoryClass: PushCampaignRepository::class)]
#[ORM\HasLifecycleCallbacks]
class PushCampaign
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\Column(length: 100)]
    private string $title = '';

    #[ORM\Column(length: 500)]
    private string $body = '';

    /** The promotion a tap opens, if any. */
    #[ORM\ManyToOne]
    #[ORM\JoinColumn(onDelete: 'SET NULL')]
    private ?Promotion $promotion = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(onDelete: 'SET NULL')]
    private ?User $sentBy = null;

    /** Customer phones it was sent to. */
    #[ORM\Column]
    private int $recipients = 0;

    /** Phones Firebase accepted it for; null when push is off on the server. */
    #[ORM\Column(nullable: true)]
    private ?int $delivered = null;

    #[ORM\Column]
    private ?\DateTimeImmutable $sentAt = null;

    #[ORM\PrePersist]
    public function onPrePersist(): void
    {
        $this->sentAt ??= new \DateTimeImmutable();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getTitle(): string
    {
        return $this->title;
    }

    public function setTitle(string $title): static
    {
        $this->title = $title;

        return $this;
    }

    public function getBody(): string
    {
        return $this->body;
    }

    public function setBody(string $body): static
    {
        $this->body = $body;

        return $this;
    }

    public function getPromotion(): ?Promotion
    {
        return $this->promotion;
    }

    public function setPromotion(?Promotion $promotion): static
    {
        $this->promotion = $promotion;

        return $this;
    }

    public function getSentBy(): ?User
    {
        return $this->sentBy;
    }

    public function setSentBy(?User $sentBy): static
    {
        $this->sentBy = $sentBy;

        return $this;
    }

    public function getRecipients(): int
    {
        return $this->recipients;
    }

    public function setRecipients(int $recipients): static
    {
        $this->recipients = $recipients;

        return $this;
    }

    public function getDelivered(): ?int
    {
        return $this->delivered;
    }

    public function setDelivered(?int $delivered): static
    {
        $this->delivered = $delivered;

        return $this;
    }

    public function getSentAt(): ?\DateTimeImmutable
    {
        return $this->sentAt;
    }
}
