<?php

namespace App\Tests\Integration;

use Doctrine\DBAL\Connection;
use PHPUnit\Framework\Attributes\After;
use PHPUnit\Framework\Attributes\Before;

/**
 * Promotions now take money off orders, and the test database is shared
 * by every test: a promotion left running would quietly discount orders
 * in tests that come after. Tests that create promotions switch theirs
 * off when they finish.
 */
trait SwitchesOffItsPromotions
{
    private ?\DateTimeImmutable $promotionsSince = null;

    #[Before(priority: 100)]
    protected function noteWhenThisTestStarted(): void
    {
        $this->promotionsSince = new \DateTimeImmutable('-1 second');
    }

    #[After(priority: 100)]
    protected function switchOffThisTestsPromotions(): void
    {
        if (null === $this->promotionsSince) {
            return;
        }

        static::getContainer()->get(Connection::class)->executeStatement(
            'UPDATE promotion SET is_active = false WHERE created_at >= :since',
            ['since' => $this->promotionsSince->format('Y-m-d H:i:s')],
        );
        // The next test may call createClient(), which needs the kernel off.
        static::ensureKernelShutdown();
    }
}
