<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Seeds the Bizerte delivery zones and their fixed delivery fees.
 */
final class Version20260909170415 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Seed delivery zones (Bizerte area) with their delivery fees';
    }

    public function up(Schema $schema): void
    {
        foreach ($this->zones() as [$name, $fee]) {
            $this->addSql(
                'INSERT INTO delivery_zone (name, fee, created_at, updated_at) VALUES (?, ?, NOW(), NOW())',
                [$name, $fee]
            );
        }
    }

    public function down(Schema $schema): void
    {
        foreach ($this->zones() as [$name, $fee]) {
            $this->addSql('DELETE FROM delivery_zone WHERE name = ?', [$name]);
        }
    }

    /**
     * @return list<array{0: string, 1: string}>
     */
    private function zones(): array
    {
        return [
            // 4 DT
            ['Bizerte centre', '4.000'],
            ['Corniche', '4.000'],
            ["L'Bhira", '4.000'],
            ['Ain Mariem', '4.000'],
            ['Boukhris', '4.000'],
            ['Kodia', '4.000'],
            ['Hay Jala2', '4.000'],
            ['Hay Weli', '4.000'],
            ['Hay Nakhla', '4.000'],
            ['Hay Lweha', '4.000'],
            ['Borj Ghamez', '4.000'],
            ['Hay Lhane', '4.000'],
            ['Wed Harega', '4.000'],
            ['Sidi Salem', '4.000'],
            ['Rawebi', '4.000'],
            ['Quartiers arabes', '4.000'],
            // 5 DT
            ['Jarzouna', '5.000'],
            ['Labreche', '5.000'],
            ['Sekma', '5.000'],
            ['Hay Sanawber', '5.000'],
            // 6 DT
            ['Bir Masyougha', '6.000'],
            ["Hafr M'hour", '6.000'],
            ['Lapicheri', '6.000'],
            // 7 DT
            ['Manzel Jmil', '7.000'],
            ['Manzel Abd Rahmen', '7.000'],
            ['Nadhour', '7.000'],
            ['Ebni Nefa3', '7.000'],
        ];
    }
}
