<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Promotion codes are now saved trimmed, and a blank one as no code. Fixes
 * those saved before: a stray space made a code impossible to use, and a
 * blank one stopped the promotion from applying by itself.
 */
final class Version20261008150000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Trim promotion codes; a blank code is no code';
    }

    public function up(Schema $schema): void
    {
        $this->addSql("UPDATE promotion SET promo_code = NULLIF(TRIM(promo_code), '') WHERE promo_code IS NOT NULL AND promo_code <> TRIM(promo_code) OR promo_code = ''");
    }

    public function down(Schema $schema): void
    {
        // Nothing to restore: the spaces carried no meaning.
    }
}
