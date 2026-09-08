<?php

namespace App\Util;

/**
 * Converts decimal amount strings (as stored in `decimal(10,3)` columns) to
 * and from integer millimes, so order totals can be summed without
 * floating-point rounding error.
 */
final class Money
{
    private function __construct()
    {
    }

    public static function toMillimes(string $amount): int
    {
        [$whole, $decimal] = array_pad(
            explode('.', $amount, 2),
            2,
            ''
        );

        $decimal = str_pad($decimal, 3, '0');

        return ((int) $whole * 1000)
            + (int) substr($decimal, 0, 3);
    }

    public static function fromMillimes(int $millimes): string
    {
        $whole = intdiv($millimes, 1000);
        $decimal = $millimes % 1000;

        return sprintf('%d.%03d', $whole, $decimal);
    }
}
