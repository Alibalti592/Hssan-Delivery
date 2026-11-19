<?php

namespace App\Service;

use App\Enum\DeliveryStatus;
use App\Event\DeliveryStatusChangedEvent;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;
use Symfony\Contracts\Cache\CacheInterface;

/**
 * The cached ranking of PopularityService, cleared whenever it may have
 * changed: an order delivered (or no longer), or a delivered one deleted.
 * Otherwise it lasts the pool's ten minutes (config/packages/cache.yaml).
 */
#[AsEventListener(event: DeliveryStatusChangedEvent::class)]
final class PopularityCache
{
    public const KEYS = ['popular.restaurants', 'popular.dishes'];

    public function __construct(
        #[Autowire(service: 'cache.popular')]
        private readonly CacheInterface $cache,
    ) {
    }

    public function __invoke(DeliveryStatusChangedEvent $event): void
    {
        if (DeliveryStatus::DELIVERED === $event->delivery->getStatus()
            || DeliveryStatus::DELIVERED === $event->previousStatus) {
            $this->clear();
        }
    }

    /**
     * @template T
     *
     * @param callable(): T $compute
     *
     * @return T
     */
    public function get(string $key, callable $compute): mixed
    {
        return $this->cache->get($key, static fn () => $compute());
    }

    public function clear(): void
    {
        foreach (self::KEYS as $key) {
            $this->cache->delete($key);
        }
    }
}
