<?php

namespace App\EventListener;

use App\Exception\ValidationFailedException;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\ExceptionEvent;
use Symfony\Component\HttpKernel\KernelEvents;

#[AsEventListener(event: KernelEvents::EXCEPTION)]
final class ValidationExceptionListener
{
    public function __invoke(ExceptionEvent $event): void
    {
        $exception = $event->getThrowable();

        if (!$exception instanceof ValidationFailedException) {
            return;
        }

        $event->setResponse(new JsonResponse(
            [
                'message' => 'Validation failed.',
                'errors' => $exception->getErrors(),
            ],
            Response::HTTP_UNPROCESSABLE_ENTITY
        ));
    }
}
