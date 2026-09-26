<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260926093359 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add product options (sizes/portions with their own price) and the option chosen on each order item';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE order_item ADD option_name VARCHAR(50) DEFAULT NULL');
        // Existing products get an empty option list; the default is only
        // there to backfill them, the mapping itself has none.
        $this->addSql("ALTER TABLE product ADD options JSON DEFAULT '[]' NOT NULL");
        $this->addSql('ALTER TABLE product ALTER options DROP DEFAULT');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE order_item DROP option_name');
        $this->addSql('ALTER TABLE product DROP options');
    }
}
