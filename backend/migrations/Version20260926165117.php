<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20260926165117 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Fixed-price offer promotions: included items, the product they are ordered as, and an optional end date';
    }

    public function up(Schema $schema): void
    {
        // Existing promotions get an empty item list; the default is dropped
        // right after so the column matches its mapping (no DB default).
        $this->addSql("ALTER TABLE promotion ADD items JSON DEFAULT '[]' NOT NULL");
        $this->addSql('ALTER TABLE promotion ALTER items DROP DEFAULT');
        $this->addSql('ALTER TABLE promotion ADD product_id INT DEFAULT NULL');
        $this->addSql('ALTER TABLE promotion ALTER end_at DROP NOT NULL');
        $this->addSql('ALTER TABLE promotion ADD CONSTRAINT FK_C11D7DD14584665A FOREIGN KEY (product_id) REFERENCES product (id) ON DELETE SET NULL NOT DEFERRABLE');
        $this->addSql('CREATE UNIQUE INDEX UNIQ_C11D7DD14584665A ON promotion (product_id)');
    }

    public function down(Schema $schema): void
    {
        // Promotions saved without an end date have to get one before
        // end_at can be NOT NULL again.
        $this->addSql('UPDATE promotion SET end_at = start_at + INTERVAL \'1 year\' WHERE end_at IS NULL');
        $this->addSql('ALTER TABLE promotion DROP CONSTRAINT FK_C11D7DD14584665A');
        $this->addSql('DROP INDEX UNIQ_C11D7DD14584665A');
        $this->addSql('ALTER TABLE promotion DROP items');
        $this->addSql('ALTER TABLE promotion DROP product_id');
        $this->addSql('ALTER TABLE promotion ALTER end_at SET NOT NULL');
    }
}
