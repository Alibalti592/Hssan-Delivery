<?php

namespace App\Controller\Api;

use App\Repository\DeliveryZoneRepository;
use App\Repository\OrderRepository;
use App\Repository\RestaurantRepository;
use App\Repository\UserRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

/**
 * Summary counts for the admin dashboard overview. Backed by COUNT queries
 * rather than "fetch every list and count the items client-side" — the
 * latter silently goes wrong once any list exceeds a single page.
 */
#[Route('/api/admin/stats')]
#[IsGranted('ROLE_ADMIN')]
final class AdminStatsController extends AbstractController
{
    public function __construct(
        private readonly RestaurantRepository $restaurantRepository,
        private readonly DeliveryZoneRepository $deliveryZoneRepository,
        private readonly UserRepository $userRepository,
        private readonly OrderRepository $orderRepository,
    ) {
    }

    #[Route('', name: 'api_admin_stats', methods: ['GET'])]
    public function summary(): JsonResponse
    {
        return $this->json([
            'restaurants' => $this->restaurantRepository->count([]),
            'deliveryZones' => $this->deliveryZoneRepository->count([]),
            'couriers' => $this->userRepository->countCouriers(),
            'totalOrders' => $this->orderRepository->count([]),
            'activeOrders' => $this->orderRepository->countActive(),
        ]);
    }
}
