<?php

namespace App\Exception;

/**
 * @phpstan-type ValidationError array{field: string, message: string}
 */
final class ValidationFailedException extends \RuntimeException
{
    /**
     * @param list<array{field: string, message: string}> $errors
     */
    public function __construct(private readonly array $errors)
    {
        parent::__construct('Validation failed.');
    }

    /**
     * @return list<array{field: string, message: string}>
     */
    public function getErrors(): array
    {
        return $this->errors;
    }
}
