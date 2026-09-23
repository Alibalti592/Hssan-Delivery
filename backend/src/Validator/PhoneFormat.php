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

    public const MESSAGE = 'Please enter a valid phone number.';
}
