<?php

namespace App\Controller\Api;

use App\Dto\Admin\ProductResponse;
use App\Dto\Admin\RestaurantResponse;
use App\Service\ProductService;
use App\Service\RestaurantService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;

/**
 * The home screen's "Rechercher un plat, un restaurant": restaurants and
 * grocery stores by name, and dishes with the place that sells them. Only
 * what a client could order right now (same rules as the catalogue).
 */
final class SearchController extends AbstractController
{
    private const MIN_LENGTH = 2;
    private const MAX_RESTAURANTS = 10;
    private const MAX_PRODUCTS = 30;

    public function __construct(
        private readonly RestaurantService $restaurantService,
        private readonly ProductService $productService,
    ) {
    }

    #[Route('/api/search', name: 'api_search', methods: ['GET'])]
    public function search(Request $request): JsonResponse
    {
        $term = trim((string) $request->query->get('q'));

        if (mb_strlen($term) < self::MIN_LENGTH) {
            return $this->json(['restaurants' => [], 'products' => []]);
        }

        $term = mb_substr($term, 0, 100);

        return $this->json([
            'restaurants' => array_map(
                static fn ($restaurant) => RestaurantResponse::fromEntity($restaurant),
                $this->restaurantService->searchAvailable($term, self::MAX_RESTAURANTS)
            ),
            'products' => array_map(
                static fn ($product) => ProductResponse::fromEntity($product) + [
                    'restaurant' => RestaurantResponse::fromEntity($product->getRestaurant()),
                ],
                $this->productService->searchAvailable($term, self::MAX_PRODUCTS)
            ),
        ]);
    }
}
