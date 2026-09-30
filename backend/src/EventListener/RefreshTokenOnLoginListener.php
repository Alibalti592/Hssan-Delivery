<?php

namespace App\EventListener;

use App\Entity\User;
use App\Service\RefreshTokenService;
use Lexik\Bundle\JWTAuthenticationBundle\Event\AuthenticationSuccessEvent;
use Lexik\Bundle\JWTAuthenticationBundle\Events;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;
use Symfony\Component\HttpFoundation\RequestStack;

/**
 * Adds a refresh token to the mobile app's login response, so it can stay
 * signed in past the JWT's one hour (see RefreshTokenService). The admin
 * dashboard (X-Client-Platform: web) keeps its httpOnly cookie and never
 * gets one: a token readable by page scripts is what the cookie avoids.
 */
#[AsEventListener(event: Events::AUTHENTICATION_SUCCESS)]
final class RefreshTokenOnLoginListener
{
    public function __construct(
        private readonly RefreshTokenService $refreshTokens,
        private readonly RequestStack $requestStack,
    ) {
    }

    public function __invoke(AuthenticationSuccessEvent $event): void
    {
        $user = $event->getUser();
        $request = $this->requestStack->getCurrentRequest();
        if (!$user instanceof User || 'web' === $request?->headers->get('X-Client-Platform')) {
            return;
        }

        $data = $event->getData();
        $data['refreshToken'] = $this->refreshTokens->issue($user);
        $event->setData($data);
    }
}
