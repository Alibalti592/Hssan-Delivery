<?php

namespace App\Pagination;

/**
 * @template T
 */
final class PaginatedResult
{
    /**
     * @param T[] $items
     */
    public function __construct(
        public readonly array $items,
        public readonly int $total,
        public readonly int $page,
        public readonly int $limit,
    ) {
    }

    public function pages(): int
    {
        return $this->limit > 0 ? (int) ceil($this->total / $this->limit) : 0;
    }
}
