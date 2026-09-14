<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20260914142705 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add pickup_address/recipient_name/recipient_phone to order and make restaurant optional (Colis parcel orders)';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE "order" ADD pickup_address TEXT DEFAULT NULL');
        $this->addSql('ALTER TABLE "order" ADD recipient_name VARCHAR(255) DEFAULT NULL');
        $this->addSql('ALTER TABLE "order" ADD recipient_phone VARCHAR(30) DEFAULT NULL');
        $this->addSql('ALTER TABLE "order" ALTER restaurant_id DROP NOT NULL');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE "order" DROP pickup_address');
        $this->addSql('ALTER TABLE "order" DROP recipient_name');
        $this->addSql('ALTER TABLE "order" DROP recipient_phone');
        $this->addSql('ALTER TABLE "order" ALTER restaurant_id SET NOT NULL');
    }
}
