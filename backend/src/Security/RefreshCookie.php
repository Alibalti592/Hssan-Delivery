<?php

namespace App\Security;

use App\Service\RefreshTokenService;
use Symfony\Component\HttpFoundation\Cookie;
use Symfony\Component\HttpFoundation\Request;

/**
 * The admin dashboard's refresh token, kept where its scripts can't read
 * it: an httpOnly cookie sent only to /api/auth (refresh and logout). The
 * mobile app gets its refresh token in the login response body instead.
 */
final class RefreshCookie
{
    public const NAME = 'REFRESH';
    private const PATH = '/api/auth';

    public function __construct(
        private readonly bool $jwtCookieSecure,
        private readonly string $jwtCookieSameSite,
    ) {
    }

    public function create(string $refreshToken): Cookie
    {
        return Cookie::create(self::NAME)
            ->withValue($refreshToken)
            ->withExpires(new \DateTimeImmutable(RefreshTokenService::TTL))
            ->withPath(self::PATH)
            ->withSecure($this->jwtCookieSecure)
            ->withHttpOnly(true)
            ->withSameSite($this->jwtCookieSameSite);
    }

    public function clear(): Cookie
    {
        return Cookie::create(self::NAME)
            ->withValue('')
            ->withExpires(1)
            ->withPath(self::PATH)
            ->withSecure($this->jwtCookieSecure)
            ->withHttpOnly(true)
            ->withSameSite($this->jwtCookieSameSite);
    }

    public static function from(Request $request): ?string
    {
        $value = $request->cookies->get(self::NAME);

        return \is_string($value) && '' !== $value ? $value : null;
    }
}
