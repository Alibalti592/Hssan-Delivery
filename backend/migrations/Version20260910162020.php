<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20260910162020 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add photo_filename to restaurant and product';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE product ADD photo_filename VARCHAR(255) DEFAULT NULL');
        $this->addSql('ALTER TABLE restaurant ADD photo_filename VARCHAR(255) DEFAULT NULL');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE product DROP photo_filename');
        $this->addSql('ALTER TABLE restaurant DROP photo_filename');
    }
}
