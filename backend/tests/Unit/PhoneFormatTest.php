<?php

namespace App\Tests\Unit;

use App\Validator\PhoneFormat;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class PhoneFormatTest extends TestCase
{
    #[DataProvider('validNumbers')]
    public function testMatchesAValidNumber(string $phone): void
    {
        self::assertSame(1, preg_match(PhoneFormat::PATTERN, $phone));
    }

    public static function validNumbers(): array
    {
        return [
            'bare 8 digits' => ['22334455'],
            'with +216 prefix' => ['+21622334455'],
            'with 216 prefix, no plus' => ['21622334455'],
            'formatted like the mobile app hint' => ['+216 22 334 455'],
            'dash-separated' => ['216-22-334-455'],
            'starts with 9' => ['91234567'],
        ];
    }

    #[DataProvider('invalidNumbers')]
    public function testRejectsAnInvalidNumber(string $phone): void
    {
        self::assertSame(0, preg_match(PhoneFormat::PATTERN, $phone));
    }

    public static function invalidNumbers(): array
    {
        return [
            'letters' => ['abcdefgh'],
            'too short' => ['1234567'],
            'too long' => ['223344556'],
            'starts with 0' => ['02233445'],
            'starts with 1' => ['12233445'],
            'empty' => [''],
        ];
    }
}
