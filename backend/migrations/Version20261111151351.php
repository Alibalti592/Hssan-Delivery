<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * What a customer can add to a dish (sauces, extras, a drink...), and what
 * was added to each order line. Every existing product and order line
 * starts with none.
 */
final class Version20261111151351 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Products get extra choices (sauces, extras, drinks...) and order lines the ones picked';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE order_item ADD extras JSON DEFAULT \'[]\' NOT NULL');
        $this->addSql('ALTER TABLE product ADD extra_groups JSON DEFAULT \'[]\' NOT NULL');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE order_item DROP extras');
        $this->addSql('ALTER TABLE product DROP extra_groups');
    }
}
