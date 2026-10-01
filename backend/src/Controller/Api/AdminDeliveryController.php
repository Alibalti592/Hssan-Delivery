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

    /**
     * The dispatch queue: orders waiting for the admin to give them to a
     * courier, oldest first. Polled by the dashboard to alert on new ones.
     */
    #[Route('/waiting', name: 'api_admin_delivery_waiting', methods: ['GET'])]
    public function waiting(): JsonResponse
    {
        return $this->json(array_map(
            static fn ($delivery) => DeliveryResponse::fromEntity($delivery),
            $this->deliveryRepository->findWaitingForCourier()
        ));
    }

    #[Route('/{id}', name: 'api_admin_delivery_show', methods: ['GET'], requirements: ['id' => '\d+'])]
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
