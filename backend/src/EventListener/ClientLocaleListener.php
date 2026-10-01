<?php

namespace App\EventListener;

use Symfony\Component\EventDispatcher\Attribute\AsEventListener;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * The mobile app is in French, the admin dashboard in English: requests
 * from the dashboard (X-Client-Platform: web) get English messages,
 * everything else the French default.
 */
#[AsEventListener(event: KernelEvents::REQUEST, priority: 20)]
final class ClientLocaleListener
{
    public function __invoke(RequestEvent $event): void
    {
        $request = $event->getRequest();
        if ('web' === $request->headers->get('X-Client-Platform')) {
            $request->setLocale('en');
        }
    }
}
