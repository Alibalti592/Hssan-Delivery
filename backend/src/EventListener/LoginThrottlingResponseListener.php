<?php

namespace App\EventListener;

use Lexik\Bundle\JWTAuthenticationBundle\Event\AuthenticationFailureEvent;
use Lexik\Bundle\JWTAuthenticationBundle\Events;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Exception\TooManyLoginAttemptsAuthenticationException;

/**
 * Lexik's failure handler maps an AuthenticationException to an HTTP status
 * purely from its ->getCode(), which TooManyLoginAttemptsAuthenticationException
 * never sets — so a throttled login would otherwise come back as a plain 401
 * indistinguishable from wrong credentials. This corrects it to 429.
 */
#[AsEventListener(event: Events::AUTHENTICATION_FAILURE)]
final class LoginThrottlingResponseListener
{
    public function __invoke(AuthenticationFailureEvent $event): void
    {
        $exception = $event->getException();

        if (!$exception instanceof TooManyLoginAttemptsAuthenticationException) {
            return;
        }

        $message = strtr($exception->getMessageKey(), $exception->getMessageData());

        $event->setResponse(new JsonResponse(
            ['message' => $message],
            Response::HTTP_TOO_MANY_REQUESTS
        ));
    }
}
