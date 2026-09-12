<?php

namespace App\Controller\Api;

use App\Pagination\PaginatedResult;
use App\Pagination\Paginator;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

/**
 * Shared by list endpoints that support `?page=&limit=` pagination. A trait
 * rather than a base-class method since some of those controllers extend
 * the plain Symfony AbstractController directly (no need for
 * AbstractApiController's deserializeAndValidate) — this works on either.
 */
trait PaginationParamsTrait
{
    protected function paginationPage(Request $request): int
    {
        return max(1, $request->query->getInt('page', 1));
    }

    protected function paginationLimit(Request $request): int
    {
        $limit = $request->query->getInt('limit', Paginator::DEFAULT_LIMIT);

        return max(1, min(Paginator::MAX_LIMIT, $limit));
    }

    /**
     * @template T
     *
     * @param PaginatedResult<T> $result
     * @param callable(T): array $mapper
     */
    protected function paginatedJson(PaginatedResult $result, callable $mapper): JsonResponse
    {
        return $this->json([
            'items' => array_map($mapper, $result->items),
            'meta' => [
                'page' => $result->page,
                'limit' => $result->limit,
                'total' => $result->total,
                'pages' => $result->pages(),
            ],
        ]);
    }
}
