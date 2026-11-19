<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * One order per checkout: the app's clientRequestId, unique per customer,
 * so a checkout retried after a lost answer doesn't place a second order.
 */
final class Version20261119162910 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Order client_request_id, unique per customer';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE "order" ADD client_request_id VARCHAR(64) DEFAULT NULL');
        $this->addSql('CREATE UNIQUE INDEX uniq_order_user_request ON "order" (user_id, client_request_id)');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('DROP INDEX uniq_order_user_request');
        $this->addSql('ALTER TABLE "order" DROP client_request_id');
    }
}
