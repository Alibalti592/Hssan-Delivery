<?php

namespace App\Controller\Api;

use App\Dto\Admin\OrderResponse;
use App\Repository\OrderRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/api/admin/orders')]
#[IsGranted('ROLE_ADMIN')]
final class AdminOrderController extends AbstractController
{
    public function __construct(
        private readonly OrderRepository $orderRepository,
    ) {
    }

    #[Route('', name: 'api_admin_order_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $orders = $this->orderRepository->findAllOrderedByCreatedAtDesc();

        return $this->json(
            array_map(
                static fn ($order) => OrderResponse::fromEntity($order),
                $orders
            )
        );
    }

    #[Route('/{id}', name: 'api_admin_order_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $order = $this->orderRepository->find($id);

        if (null === $order) {
            return $this->json(
                ['message' => 'Order not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(
            OrderResponse::fromEntity($order)
        );
    }
}
