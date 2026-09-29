<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Saved addresses remember their delivery zone and map pin; orders keep
 * the pins the client placed, for the courier's "Ouvrir dans Maps".
 */
final class Version20260929151514 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Address zone and map location; order pickup/delivery coordinates';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE address ADD latitude DOUBLE PRECISION DEFAULT NULL');
        $this->addSql('ALTER TABLE address ADD longitude DOUBLE PRECISION DEFAULT NULL');
        $this->addSql('ALTER TABLE address ADD delivery_zone_id INT DEFAULT NULL');
        $this->addSql('ALTER TABLE address ADD CONSTRAINT FK_D4E6F8195328075 FOREIGN KEY (delivery_zone_id) REFERENCES delivery_zone (id) ON DELETE SET NULL NOT DEFERRABLE');
        $this->addSql('CREATE INDEX IDX_D4E6F8195328075 ON address (delivery_zone_id)');
        $this->addSql('ALTER TABLE "order" ADD delivery_latitude DOUBLE PRECISION DEFAULT NULL');
        $this->addSql('ALTER TABLE "order" ADD delivery_longitude DOUBLE PRECISION DEFAULT NULL');
        $this->addSql('ALTER TABLE "order" ADD pickup_latitude DOUBLE PRECISION DEFAULT NULL');
        $this->addSql('ALTER TABLE "order" ADD pickup_longitude DOUBLE PRECISION DEFAULT NULL');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE address DROP CONSTRAINT FK_D4E6F8195328075');
        $this->addSql('DROP INDEX IDX_D4E6F8195328075');
        $this->addSql('ALTER TABLE address DROP latitude');
        $this->addSql('ALTER TABLE address DROP longitude');
        $this->addSql('ALTER TABLE address DROP delivery_zone_id');
        $this->addSql('ALTER TABLE "order" DROP delivery_latitude');
        $this->addSql('ALTER TABLE "order" DROP delivery_longitude');
        $this->addSql('ALTER TABLE "order" DROP pickup_latitude');
        $this->addSql('ALTER TABLE "order" DROP pickup_longitude');
    }
}
