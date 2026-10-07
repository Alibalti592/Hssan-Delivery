<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Promotions now take money off orders: each order records how much, and
 * which promotion (title and code copied, in case it is edited later).
 */
final class Version20261001170841 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Orders keep the promotion discount they got';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE "order" ADD discount_amount NUMERIC(10, 3) DEFAULT \'0.000\' NOT NULL');
        $this->addSql('ALTER TABLE "order" ADD promotion_title VARCHAR(255) DEFAULT NULL');
        $this->addSql('ALTER TABLE "order" ADD promo_code VARCHAR(50) DEFAULT NULL');
        $this->addSql('ALTER TABLE "order" ADD promotion_id INT DEFAULT NULL');
        $this->addSql('ALTER TABLE "order" ADD CONSTRAINT FK_F5299398139DF194 FOREIGN KEY (promotion_id) REFERENCES promotion (id) ON DELETE SET NULL NOT DEFERRABLE');
        $this->addSql('CREATE INDEX IDX_F5299398139DF194 ON "order" (promotion_id)');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE "order" DROP CONSTRAINT FK_F5299398139DF194');
        $this->addSql('DROP INDEX IDX_F5299398139DF194');
        $this->addSql('ALTER TABLE "order" DROP discount_amount');
        $this->addSql('ALTER TABLE "order" DROP promotion_title');
        $this->addSql('ALTER TABLE "order" DROP promo_code');
        $this->addSql('ALTER TABLE "order" DROP promotion_id');
    }
}
