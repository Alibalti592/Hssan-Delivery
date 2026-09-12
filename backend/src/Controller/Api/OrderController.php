<?php

namespace App\Controller\Api;

use App\Dto\Order\CreateOrderRequest;
use App\Dto\Order\OrderResponse;
use App\Service\OrderService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/orders')]
final class OrderController extends AbstractApiController
{
    use PaginationParamsTrait;

    public function __construct(
        private readonly OrderService $orderService,
        SerializerInterface $serializer,
        ValidatorInterface $validator,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_orders_list', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $result = $this->orderService->getUserOrders(
            $user,
            $this->paginationPage($request),
            $this->paginationLimit($request)
        );

        return $this->paginatedJson($result, static fn (\App\Entity\Order $order) => OrderResponse::fromEntity($order));
    }

    #[Route('/{id}', name: 'api_orders_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $order = $this->orderService->getUserOrder($id, $user);

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

    #[Route('', name: 'api_orders_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        /** @var CreateOrderRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateOrderRequest::class);

        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $order = $this->orderService->createOrder($dto, $user);

        return $this->json(
            OrderResponse::fromEntity($order),
            Response::HTTP_CREATED
        );
    }
}
