<?php

namespace App\Exception;

use Symfony\Component\HttpFoundation\Response;

/**
 * The request is well-formed but cannot be carried out: it references entities
 * that don't fit together (a category from another restaurant), or asks for a
 * state transition that isn't allowed from where the resource currently is
 * (accepting a delivery that is still pending).
 */
final class InvalidOperationException extends DomainException
{
    public function statusCode(): int
    {
        return Response::HTTP_BAD_REQUEST;
    }
}
