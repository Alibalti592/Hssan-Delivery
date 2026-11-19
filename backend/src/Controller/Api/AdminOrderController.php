<?php

namespace App\Controller\Api;

use App\Dto\Admin\OrderResponse;
use App\Repository\OrderRepository;
use App\Service\OrderDeletion;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/api/admin/orders')]
#[IsGranted('ROLE_ADMIN')]
final class AdminOrderController extends AbstractController
{
    use PaginationParamsTrait;

    public function __construct(
        private readonly OrderRepository $orderRepository,
        private readonly OrderDeletion $orderDeletion,
    ) {
    }

    #[Route('', name: 'api_admin_order_list', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        $result = $this->orderRepository->paginateAllOrderedByCreatedAtDesc(
            $this->paginationPage($request),
            $this->paginationLimit($request)
        );

        return $this->paginatedJson($result, static fn ($order) => OrderResponse::fromEntity($order));
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

    /**
     * Deletes a delivered or cancelled order for good (400 for one still
     * on its way: cancel it first). See OrderDeletion.
     */
    #[Route('/{id}', name: 'api_admin_order_delete', methods: ['DELETE'], requirements: ['id' => '\d+'])]
    public function delete(int $id): JsonResponse
    {
        $order = $this->orderRepository->find($id);

        if (null === $order) {
            return $this->json(
                ['message' => 'Order not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $this->orderDeletion->delete($order);

        return new JsonResponse(null, Response::HTTP_NO_CONTENT);
    }
}
