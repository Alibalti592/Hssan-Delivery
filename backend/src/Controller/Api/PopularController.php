<?php

namespace App\Controller\Api;

use App\Dto\Admin\ProductResponse;
use App\Dto\Admin\RestaurantResponse;
use App\Service\PopularityService;
use App\Service\RestaurantService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;

/**
 * The home screen's "Les plus commandés" (dishes) and "Restaurants
 * populaires": real counts of delivered orders (see PopularityService).
 * Both lists are empty until enough orders have been delivered; the app
 * then leaves the sections out. Signed-in accounts only, like the rest of
 * the catalogue (security.yaml).
 */
final class PopularController extends AbstractController
{
    private const MAX_RESTAURANTS = 6;
    private const MAX_DISHES = 8;

    public function __construct(
        private readonly PopularityService $popularity,
        private readonly RestaurantService $restaurantService,
    ) {
    }

    #[Route('/api/popular', name: 'api_popular', methods: ['GET'])]
    public function popular(): JsonResponse
    {
        $now = new \DateTimeImmutable();
        $restaurants = $this->popularity->popularRestaurants($now, self::MAX_RESTAURANTS);
        $dishes = $this->popularity->popularDishes($now, self::MAX_DISHES);

        $this->restaurantService->preloadCategories([
            ...array_column($restaurants, 'restaurant'),
            ...array_map(static fn (array $d) => $d['product']->getRestaurant(), $dishes),
        ]);

        return $this->json([
            'restaurants' => array_map(
                static fn (array $r) => RestaurantResponse::fromEntity($r['restaurant']) + [
                    'orderCount' => $r['orderCount'],
                ],
                $restaurants
            ),
            'dishes' => array_map(
                static fn (array $d) => ProductResponse::fromEntity($d['product']) + [
                    'restaurant' => RestaurantResponse::fromEntity($d['product']->getRestaurant()),
                    'orderCount' => $d['orderCount'],
                ],
                $dishes
            ),
            'windowDays' => PopularityService::WINDOW_DAYS,
        ]);
    }
}
