<?php

use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;

// Plain PHP, not YAML: Symfony's enumNode (used for set_cookies.BEARER.samesite
// in this bundle's Configuration.php) validates its value against the literal
// allowed set at config-tree-processing time, before the container ever gets a
// chance to lazily resolve a "%env(...)%" placeholder — unlike a plain
// scalarNode (e.g. "secure" below), enumNode has no deferred-resolution path,
// so "%env(JWT_COOKIE_SAMESITE)%" there always fails with "the value '' is not
// allowed" regardless of what the env var is actually set to. Resolving it
// here in PHP gives the tree a real, already-resolved literal string instead.
return static function (ContainerConfigurator $container): void {
    $samesite = $_SERVER['JWT_COOKIE_SAMESITE'] ?? $_ENV['JWT_COOKIE_SAMESITE'] ?? 'lax';
    $allowedSamesite = ['none', 'lax', 'strict'];
    if (!in_array($samesite, $allowedSamesite, true)) {
        throw new \InvalidArgumentException(sprintf(
            'JWT_COOKIE_SAMESITE must be one of "%s", got "%s".',
            implode('", "', $allowedSamesite),
            $samesite,
        ));
    }

    $secure = filter_var(
        $_SERVER['JWT_COOKIE_SECURE'] ?? $_ENV['JWT_COOKIE_SECURE'] ?? false,
        FILTER_VALIDATE_BOOL,
    );

    $container->extension('lexik_jwt_authentication', [
        'secret_key' => '%env(resolve:JWT_SECRET_KEY)%',
        'public_key' => '%env(resolve:JWT_PUBLIC_KEY)%',
        'pass_phrase' => '%env(JWT_PASSPHRASE)%',

        // Mobile clients keep authenticating with "Authorization: Bearer <jwt>" —
        // authorization_header is tried first and nothing below changes that.
        // The admin dashboard (a browser SPA) instead receives its JWT as an
        // httpOnly cookie: JS on the admin dashboard can no longer read the
        // token, so an XSS there can't just lift it out of localStorage the way
        // it could before. Both extractors run on the same "api" firewall.
        'token_extractors' => [
            'authorization_header' => ['enabled' => true],
            'cookie' => ['enabled' => true, 'name' => 'BEARER'],
        ],

        // Without this, enabling cookies strips "token" from the JSON login
        // response body by default. Mobile needs it there — it never reads the
        // cookie — so keep it in the body for both clients.
        'remove_token_from_body_when_cookies_used' => false,

        'set_cookies' => [
            'BEARER' => [
                // 'lax' works when the admin dashboard and backend share a
                // site (e.g. both under hssan.example). It must become
                // 'none' if they ever sit on different sites (e.g. an admin
                // dashboard on Vercel calling a backend on Railway) — a Lax
                // cookie is silently not sent on cross-site fetch/XHR calls,
                // so login would appear to succeed and then every request
                // after it would look signed out. 'none' additionally
                // requires secure: true (browsers reject a non-Secure
                // SameSite=None cookie outright) — see JWT_COOKIE_SECURE.
                'samesite' => $samesite,
                'httpOnly' => true,
                // Secure cookies are silently dropped by the browser over
                // plain http://, so this defaults to false for local dev.
                // It MUST be true once the admin dashboard and backend are
                // served over HTTPS — see JWT_COOKIE_SECURE in .env.example.
                'secure' => $secure,
            ],
        ],
    ]);
};
