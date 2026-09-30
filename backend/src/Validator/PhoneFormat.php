<?php

namespace App\Validator;

/**
 * Tunisian phone numbers: an optional +216/216 country code, optionally
 * separated from the local number by a space or dash, followed by 8 digits
 * (the national mobile/landline length) starting 2-9 — matches the format
 * shown to users everywhere the app asks for one (see the "+216 22 000 000"
 * hint in mobile/lib/auth/login_screen.dart and register_screen.dart).
 * Loose about internal spacing/dashes since that's exactly how the hint
 * formats it, but strict about digit count and shape so "abc" or "123" can
 * no longer be submitted as a phone number.
 */
final class PhoneFormat
{
    public const PATTERN = '/^\+?(216)?[ \-]?[2-9](?:[ \-]?\d){7}$/';

    public const MESSAGE = 'Numéro de téléphone invalide.';

    /**
     * The 8 local digits of a number, however it was typed: "+216 22 123
     * 456", "216-22123456" and "22 123 456" all give "22123456". Accounts
     * are stored in this form so the same number always finds the same
     * account.
     */
    public static function normalize(string $phone): string
    {
        $digits = preg_replace('/\D/', '', $phone) ?? '';

        if (11 === \strlen($digits) && str_starts_with($digits, '216')) {
            return substr($digits, 3);
        }

        return $digits;
    }
}
