<?php

namespace App\Tests\Support;

use Doctrine\DBAL\Driver;
use Doctrine\DBAL\Driver\Connection;
use Doctrine\DBAL\Driver\Middleware;
use Doctrine\DBAL\Driver\Middleware\AbstractConnectionMiddleware;
use Doctrine\DBAL\Driver\Middleware\AbstractDriverMiddleware;
use Doctrine\DBAL\Driver\Middleware\AbstractStatementMiddleware;
use Doctrine\DBAL\Driver\Result;
use Doctrine\DBAL\Driver\Statement;

/**
 * Counts the SQL statements the app runs, in tests only (services.yaml,
 * when@test): QueryCountTest uses it to keep lists from going back to one
 * query per row (N+1).
 *
 * The log is static: Doctrine wires its own copy of each middleware per
 * connection, so the instance a test can fetch isn't the one counting.
 */
final class QueryCounter implements Middleware
{
    /** @var list<string> */
    public static array $queries = [];

    public static function reset(): void
    {
        self::$queries = [];
    }

    public static function count(): int
    {
        return count(self::$queries);
    }

    public function wrap(Driver $driver): Driver
    {
        return new class($driver) extends AbstractDriverMiddleware {
            public function connect(array $params): Connection
            {
                return new class(parent::connect($params)) extends AbstractConnectionMiddleware {
                    public function prepare(string $sql): Statement
                    {
                        return new class(parent::prepare($sql), $sql) extends AbstractStatementMiddleware {
                            public function __construct(Statement $statement, private readonly string $sql)
                            {
                                parent::__construct($statement);
                            }

                            public function execute(): Result
                            {
                                QueryCounter::$queries[] = $this->sql;

                                return parent::execute();
                            }
                        };
                    }

                    public function query(string $sql): Result
                    {
                        QueryCounter::$queries[] = $sql;

                        return parent::query($sql);
                    }

                    public function exec(string $sql): int|string
                    {
                        QueryCounter::$queries[] = $sql;

                        return parent::exec($sql);
                    }
                };
            }
        };
    }
}
