<?php

namespace App\Pagination;

use Doctrine\ORM\QueryBuilder;
use Doctrine\ORM\Tools\Pagination\Paginator as DoctrinePaginator;

/**
 * Thin wrapper around Doctrine's own Paginator: applies the offset/limit for
 * a page to a QueryBuilder and returns both that page's results and the
 * total row count in one call, so callers don't hand-write a second COUNT
 * query that could drift out of sync with the first.
 */
final class Paginator
{
    public const DEFAULT_LIMIT = 20;
    public const MAX_LIMIT = 100;

    /**
     * @template T
     *
     * @param QueryBuilder $qb a query builder for entity T, not yet limited
     *
     * @return PaginatedResult<T>
     */
    public static function paginate(QueryBuilder $qb, int $page, int $limit): PaginatedResult
    {
        $page = max(1, $page);
        $limit = max(1, min(self::MAX_LIMIT, $limit));

        $qb->setFirstResult(($page - 1) * $limit)
            ->setMaxResults($limit);

        $paginator = new DoctrinePaginator($qb, fetchJoinCollection: false);

        return new PaginatedResult(
            iterator_to_array($paginator),
            count($paginator),
            $page,
            $limit
        );
    }
}
