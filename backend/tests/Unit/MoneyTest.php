<?php

namespace App\Tests\Unit;

use App\Util\Money;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class MoneyTest extends TestCase
{
    #[DataProvider('amounts')]
    public function testToMillimes(string $amount, int $expected): void
    {
        self::assertSame($expected, Money::toMillimes($amount));
    }

    #[DataProvider('amounts')]
    public function testFromMillimes(string $amount, int $millimes): void
    {
        self::assertSame($amount, Money::fromMillimes($millimes));
    }

    public static function amounts(): array
    {
        return [
            'whole number' => ['15.000', 15000],
            'one decimal digit' => ['15.500', 15500],
            'three decimal digits' => ['15.999', 15999],
            'zero' => ['0.000', 0],
            'large amount' => ['1234.567', 1234567],
        ];
    }

    public function testToMillimesPadsMissingDecimals(): void
    {
        self::assertSame(15000, Money::toMillimes('15'));
        self::assertSame(15500, Money::toMillimes('15.5'));
    }

    public function testToMillimesTruncatesExtraDecimals(): void
    {
        self::assertSame(15999, Money::toMillimes('15.9999'));
    }

    public function testSumOfMillimesRoundTripsExactly(): void
    {
        $totalMillimes = Money::toMillimes('9.990') + Money::toMillimes('0.010');

        self::assertSame('10.000', Money::fromMillimes($totalMillimes));
    }
}
