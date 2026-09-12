<?php

namespace App\Exception;

use Symfony\Component\HttpFoundation\Response;

/**
 * The request conflicts with the current state of a resource, e.g. creating a
 * second account with a phone number that is already taken.
 */
final class ConflictException extends DomainException
{
    public function statusCode(): int
    {
        return Response::HTTP_CONFLICT;
    }
}
