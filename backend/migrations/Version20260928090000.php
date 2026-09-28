<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Removes the demo accounts the fixtures seed (couriers 21000001/21000002,
 * clients 22000001/22000002) and everything they own. Their passwords are
 * published in the README, so they must not live on a real database.
 *
 * On a fresh database (CI, a new local setup) this runs before the fixtures
 * and finds nothing, so the demo accounts still exist there. The admin
 * (20000000) is never touched.
 */
final class Version20260928090000 extends AbstractMigration
{
    private const DEMO_USERS = "SELECT id FROM \"user\" WHERE phone IN ('21000001', '21000002', '22000001', '22000002') AND roles::text NOT LIKE '%ROLE_ADMIN%'";

    public function getDescription(): string
    {
        return 'Delete the seeded demo courier and client accounts and their data';
    }

    public function up(Schema $schema): void
    {
        $users = self::DEMO_USERS;
        $orders = "SELECT id FROM \"order\" WHERE user_id IN ($users)";

        $count = fn (string $sql): int => (int) $this->connection->fetchOne("SELECT COUNT(*) FROM ($sql) AS t");
        $this->write(sprintf(
            'Demo accounts: %d users, %d of their orders, %d deliveries of other customers they were assigned',
            $count($users),
            $count($orders),
            $count("SELECT id FROM delivery WHERE courier_id IN ($users) AND order_id NOT IN ($orders)"),
        ));

        // A real customer's order that a demo courier had taken on goes back
        // to waiting for a courier; finished ones keep their history and
        // just lose the courier.
        $this->addSql("UPDATE \"order\" SET status = 'PENDING', updated_at = NOW() WHERE id IN (SELECT order_id FROM delivery WHERE courier_id IN ($users) AND status IN ('ASSIGNED', 'ACCEPTED', 'PICKED_UP', 'ON_THE_WAY')) AND id NOT IN ($orders)");
        $this->addSql("UPDATE delivery SET status = 'PENDING', assigned_at = NULL, accepted_at = NULL, picked_up_at = NULL, updated_at = NOW() WHERE courier_id IN ($users) AND status IN ('ASSIGNED', 'ACCEPTED', 'PICKED_UP', 'ON_THE_WAY') AND order_id NOT IN ($orders)");
        $this->addSql("UPDATE delivery SET courier_id = NULL WHERE courier_id IN ($users) AND order_id NOT IN ($orders)");

        // The demo clients' own orders, with their items and deliveries.
        $this->addSql("DELETE FROM delivery WHERE order_id IN ($orders)");
        $this->addSql("DELETE FROM order_item WHERE order_id IN ($orders)");
        $this->addSql("DELETE FROM \"order\" WHERE user_id IN ($users)");

        $this->addSql("DELETE FROM courier_location WHERE courier_id IN ($users)");
        $this->addSql("DELETE FROM device_token WHERE user_id IN ($users)");
        $this->addSql("DELETE FROM address WHERE user_id IN ($users)");
        $this->addSql("DELETE FROM \"user\" WHERE id IN ($users)");
    }

    public function down(Schema $schema): void
    {
        $this->throwIrreversibleMigrationException('Deleted demo accounts can be re-created with the fixtures.');
    }
}
