<?php

namespace App\Controller\Api;

use App\Dto\DeliveryResponse;
use App\Repository\DeliveryRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/api/admin/deliveries')]
#[IsGranted('ROLE_ADMIN')]
final class AdminDeliveryController extends AbstractController
{
    use PaginationParamsTrait;

    public function __construct(
        private readonly DeliveryRepository $deliveryRepository,
    ) {
    }

    #[Route('', name: 'api_admin_delivery_list', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        $result = $this->deliveryRepository->paginateAllOrderedByCreatedAtDesc(
            $this->paginationPage($request),
            $this->paginationLimit($request)
        );

        return $this->paginatedJson($result, static fn ($delivery) => DeliveryResponse::fromEntity($delivery));
    }

    #[Route('/{id}', name: 'api_admin_delivery_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $delivery = $this->deliveryRepository->find($id);

        if (null === $delivery) {
            return $this->json(
                ['message' => 'Delivery not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(
            DeliveryResponse::fromEntity($delivery)
        );
    }
}
