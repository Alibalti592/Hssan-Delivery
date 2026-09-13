<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260912184443 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add is_available to user (courier self-service availability toggle)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE "user" ADD is_available BOOLEAN DEFAULT true NOT NULL');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE "user" DROP is_available');
    }
}
