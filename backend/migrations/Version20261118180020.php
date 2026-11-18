<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Indexes for the lists asked for most as orders pile up: jobs waiting for
 * a courier, the dashboard's day, popularity, a customer's orders.
 */
final class Version20261118180020 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Indexes on order and delivery status/date and push campaign date';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('CREATE INDEX idx_delivery_status_created ON delivery (status, created_at)');
        $this->addSql('CREATE INDEX idx_order_status_created ON "order" (status, created_at)');
        $this->addSql('CREATE INDEX idx_order_user_created ON "order" (user_id, created_at)');
        $this->addSql('CREATE INDEX idx_push_campaign_sent_at ON push_campaign (sent_at)');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('DROP INDEX idx_delivery_status_created');
        $this->addSql('DROP INDEX idx_order_status_created');
        $this->addSql('DROP INDEX idx_order_user_created');
        $this->addSql('DROP INDEX idx_push_campaign_sent_at');
    }
}
