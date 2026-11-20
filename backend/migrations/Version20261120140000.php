<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * More restaurant categories for the app's "Que souhaitez-vous manger ?"
 * row, after the six the client started with (Version20261111141602).
 *
 * Each is added only when no category has its name or its icon already:
 * one the admin made (or renamed) for the same food is kept, not doubled.
 * They go after the existing ones, in this order. A category shows in the
 * app once an open restaurant is ticked in it: the admin's Categories page,
 * or app:restaurant-categories:auto-assign.
 */
final class Version20261120140000 extends AbstractMigration
{
    private const CATEGORIES = [
        ['Burgers', 'burger'],
        ['Chawarma', 'kebab'],
        ['Grillades', 'grill'],
        ['Pâtes', 'pasta'],
        ['Poissons', 'fish'],
        ['Salades', 'leaf'],
        ['Petit-déjeuner', 'breakfast'],
        ['Glaces', 'ice_cream'],
        ['Café', 'coffee'],
    ];

    public function getDescription(): string
    {
        return 'Restaurant categories: add Burgers, Chawarma, Grillades, Pâtes, Poissons, Salades, Petit-déjeuner, Glaces, Café when missing';
    }

    public function up(Schema $schema): void
    {
        foreach (self::CATEGORIES as [$name, $icon]) {
            $this->addSql(
                'INSERT INTO restaurant_category (name, icon, position, created_at, updated_at)
                 SELECT CAST(:name AS VARCHAR), CAST(:icon AS VARCHAR), COALESCE(MAX(position), 0) + 1, NOW(), NOW()
                 FROM restaurant_category
                 HAVING NOT EXISTS (
                     SELECT 1 FROM restaurant_category
                     WHERE LOWER(name) = LOWER(CAST(:name AS VARCHAR)) OR icon = CAST(:icon AS VARCHAR)
                 )',
                ['name' => $name, 'icon' => $icon]
            );
        }
    }

    public function down(Schema $schema): void
    {
        // Only those still unused: a restaurant ticked in one since keeps it.
        foreach (self::CATEGORIES as [$name]) {
            $this->addSql(
                'DELETE FROM restaurant_category rc
                 WHERE rc.name = :name
                 AND NOT EXISTS (SELECT 1 FROM restaurant_restaurant_category rrc WHERE rrc.restaurant_category_id = rc.id)',
                ['name' => $name]
            );
        }
    }
}
