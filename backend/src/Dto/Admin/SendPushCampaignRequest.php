<?php

namespace App\Dto\Admin;

use Symfony\Component\Validator\Constraints as Assert;

/**
 * A notification to every customer. Lengths match what a phone shows: a
 * title on one line, a few lines of text.
 */
final class SendPushCampaignRequest
{
    #[Assert\NotBlank(message: 'Title required.', normalizer: 'trim')]
    #[Assert\Length(max: 65, maxMessage: 'Title too long (65 characters max).')]
    public ?string $title = null;

    #[Assert\NotBlank(message: 'Message required.', normalizer: 'trim')]
    #[Assert\Length(max: 240, maxMessage: 'Message too long (240 characters max).')]
    public ?string $body = null;

    /** A tap opens this promotion in the app; optional. */
    #[Assert\Positive]
    public ?int $promotionId = null;
}
