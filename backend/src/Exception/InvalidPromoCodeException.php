<?php

namespace App\Exception;

use Symfony\Component\HttpFoundation\Response;

/**
 * A promo code that gives nothing: unknown, over, or for another restaurant.
 * Its own type so OrderController can count these failed tries per account
 * and stop a script guessing codes (the app never shows them).
 */
final class InvalidPromoCodeException extends DomainException
{
    public function statusCode(): int
    {
        return Response::HTTP_BAD_REQUEST;
    }
}
