<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260913151911 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add delivery_type to order (which of the 4 client services it belongs to)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql("ALTER TABLE \"order\" ADD delivery_type VARCHAR(20) DEFAULT 'RESTAURANT' NOT NULL");
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE "order" DROP delivery_type');
    }
}
