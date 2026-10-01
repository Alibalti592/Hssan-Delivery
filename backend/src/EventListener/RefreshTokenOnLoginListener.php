<?php

namespace App\EventListener;

use App\Entity\User;
use App\Security\RefreshCookie;
use App\Service\RefreshTokenService;
use Lexik\Bundle\JWTAuthenticationBundle\Event\AuthenticationSuccessEvent;
use Lexik\Bundle\JWTAuthenticationBundle\Events;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;
use Symfony\Component\HttpFoundation\RequestStack;

/**
 * Hands out a refresh token at login, so neither client is signed out when
 * the JWT expires after an hour (see RefreshTokenService): the mobile app
 * gets it in the response body, the admin dashboard (X-Client-Platform:
 * web) in an httpOnly cookie its scripts can't read.
 */
#[AsEventListener(event: Events::AUTHENTICATION_SUCCESS)]
final class RefreshTokenOnLoginListener
{
    public function __construct(
        private readonly RefreshTokenService $refreshTokens,
        private readonly RefreshCookie $refreshCookie,
        private readonly RequestStack $requestStack,
    ) {
    }

    public function __invoke(AuthenticationSuccessEvent $event): void
    {
        $user = $event->getUser();
        if (!$user instanceof User) {
            return;
        }

        $refreshToken = $this->refreshTokens->issue($user);

        if ('web' === $this->requestStack->getCurrentRequest()?->headers->get('X-Client-Platform')) {
            $event->getResponse()->headers->setCookie($this->refreshCookie->create($refreshToken));

            return;
        }

        $data = $event->getData();
        $data['refreshToken'] = $refreshToken;
        $event->setData($data);
    }
}
