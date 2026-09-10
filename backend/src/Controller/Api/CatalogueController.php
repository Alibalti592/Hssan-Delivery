<?php

namespace App\Controller\Api;

use App\Dto\Admin\CategoryResponse;
use App\Dto\Admin\ProductResponse;
use App\Dto\Admin\RestaurantResponse;
use App\Entity\Restaurant;
use App\Service\CategoryService;
use App\Service\ProductService;
use App\Service\RestaurantService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

/**
 * The catalogue a client browses before placing an order. No #[IsGranted]
 * here — the security.yaml access_control already requires ROLE_USER (i.e.
 * any signed-in account) for all non-admin /api routes, which is all this
 * needs. Closed restaurants (isAvailable: false) are hidden entirely,
 * matching the rule OrderService already enforces at checkout, and only
 * available products are listed for the same reason.
 */
#[Route('/api/restaurants')]
final class CatalogueController extends AbstractController
{
    public function __construct(
        private readonly RestaurantService $restaurantService,
        private readonly CategoryService $categoryService,
        private readonly ProductService $productService,
    ) {
    }

    #[Route('', name: 'api_catalogue_restaurant_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $restaurants = $this->restaurantService->listAvailable();

        return $this->json(
            array_map(
                static fn ($restaurant) => RestaurantResponse::fromEntity($restaurant),
                $restaurants
            )
        );
    }

    #[Route('/{id}', name: 'api_catalogue_restaurant_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $restaurant = $this->getAvailableRestaurant($id);

        if (null === $restaurant) {
            return $this->restaurantNotFound();
        }

        return $this->json(RestaurantResponse::fromEntity($restaurant));
    }

    #[Route(
        '/{id}/categories',
        name: 'api_catalogue_category_list',
        methods: ['GET']
    )]
    public function categories(int $id): JsonResponse
    {
        $restaurant = $this->getAvailableRestaurant($id);

        if (null === $restaurant) {
            return $this->restaurantNotFound();
        }

        $categories = $this->categoryService->listForRestaurant($restaurant);

        return $this->json(
            array_map(
                static fn ($category) => CategoryResponse::fromEntity($category),
                $categories
            )
        );
    }

    #[Route(
        '/{id}/products',
        name: 'api_catalogue_product_list',
        methods: ['GET']
    )]
    public function products(int $id): JsonResponse
    {
        $restaurant = $this->getAvailableRestaurant($id);

        if (null === $restaurant) {
            return $this->restaurantNotFound();
        }

        $products = $this->productService->listAvailableForRestaurant($restaurant);

        return $this->json(
            array_map(
                static fn ($product) => ProductResponse::fromEntity($product),
                $products
            )
        );
    }

    private function getAvailableRestaurant(int $id): ?Restaurant
    {
        $restaurant = $this->restaurantService->get($id);

        if (null === $restaurant || !$restaurant->isAvailable()) {
            return null;
        }

        return $restaurant;
    }

    private function restaurantNotFound(): JsonResponse
    {
        return $this->json(
            ['message' => 'Restaurant not found.'],
            Response::HTTP_NOT_FOUND
        );
    }
}
