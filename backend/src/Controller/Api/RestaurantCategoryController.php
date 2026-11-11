<?php

namespace App\Controller\Api;

use App\Dto\Admin\RestaurantCategoryResponse;
use App\Enum\RestaurantType;
use App\Service\RestaurantCategoryService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;

/**
 * The category row a client filters the restaurant list with ("Pizza",
 * "Sucré"...). Only categories with an open restaurant behind them, so a
 * tap never lands on an empty list. Signed-in access only, through
 * security.yaml's access_control, like the catalogue.
 */
#[Route('/api/restaurant-categories')]
final class RestaurantCategoryController extends AbstractController
{
    public function __construct(
        private readonly RestaurantCategoryService $restaurantCategoryService,
    ) {
    }

    #[Route('', name: 'api_restaurant_category_list', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        // Same default as the catalogue: restaurants, unless ?type=GROCERY.
        $type = RestaurantType::tryFrom((string) $request->query->get('type')) ?? RestaurantType::RESTAURANT;

        return $this->json(array_map(
            static fn ($category) => RestaurantCategoryResponse::fromEntity($category),
            $this->restaurantCategoryService->listInUse($type)
        ));
    }
}
