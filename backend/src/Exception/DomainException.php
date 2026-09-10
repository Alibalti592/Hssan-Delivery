<?php

namespace App\Exception;

/**
 * Base for expected business-rule failures that map to a 4xx API response.
 *
 * Services throw these instead of a bare \RuntimeException so a genuine
 * runtime fault (which stays a \RuntimeException) still surfaces as a 500
 * rather than being silently turned into a client error.
 */
abstract class DomainException extends \RuntimeException
{
    abstract public function statusCode(): int;
}
