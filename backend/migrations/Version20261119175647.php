<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Indexes measured on a copy with 120,000 orders and 47,000 dishes (see the
 * performance report):
 * - order and delivery by date alone: the admin's lists, newest first, and
 *   the dashboard's day (16.7 ms -> 0.03 ms, 18.5 ms -> 0.09 ms);
 * - dish names by trigram, for search's LIKE '%...%' that no ordinary
 *   index can serve (28-44 ms -> 0.03-8 ms). Doctrine can't describe this
 *   one, so it lives here only; its schema tool leaves it alone;
 * - order by customer alone dropped: (user_id, created_at) and the unique
 *   (user_id, client_request_id) both start with it.
 */
final class Version20261119175647 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Indexes: order and delivery dates, dish name trigrams; drop the redundant order customer index';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('CREATE INDEX idx_delivery_created ON delivery (created_at)');
        $this->addSql('CREATE INDEX idx_order_created ON "order" (created_at)');
        $this->addSql('CREATE EXTENSION IF NOT EXISTS pg_trgm');
        $this->addSql('CREATE INDEX idx_product_name_trgm ON product USING gin (LOWER(name) gin_trgm_ops)');
        $this->addSql('DROP INDEX IF EXISTS idx_f5299398a76ed395');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('CREATE INDEX idx_f5299398a76ed395 ON "order" (user_id)');
        $this->addSql('DROP INDEX idx_product_name_trgm');
        $this->addSql('DROP INDEX idx_delivery_created');
        $this->addSql('DROP INDEX idx_order_created');
    }
}
