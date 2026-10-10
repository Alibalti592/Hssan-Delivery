<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Delivery zones on the map: a center and the radius it covers, so an
 * address pin gets its zone automatically. Null until the admin places it.
 */
final class Version20261011090000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Delivery zones get a center and a radius';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE delivery_zone ADD latitude DOUBLE PRECISION DEFAULT NULL');
        $this->addSql('ALTER TABLE delivery_zone ADD longitude DOUBLE PRECISION DEFAULT NULL');
        $this->addSql('ALTER TABLE delivery_zone ADD radius_km DOUBLE PRECISION DEFAULT NULL');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE delivery_zone DROP latitude');
        $this->addSql('ALTER TABLE delivery_zone DROP longitude');
        $this->addSql('ALTER TABLE delivery_zone DROP radius_km');
    }
}
