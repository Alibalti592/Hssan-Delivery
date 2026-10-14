<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Standard or express delivery per order; every existing order was standard.
 */
final class Version20261014090000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Orders get a delivery speed (standard or express)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql("ALTER TABLE \"order\" ADD delivery_speed VARCHAR(20) DEFAULT 'STANDARD' NOT NULL");
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE "order" DROP delivery_speed');
    }
}
