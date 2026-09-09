<?php

namespace App\Controller\Api;

use App\Dto\DeliveryResponse;
use App\Repository\DeliveryRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/api/admin/deliveries')]
#[IsGranted('ROLE_ADMIN')]
final class AdminDeliveryController extends AbstractController
{
    public function __construct(
        private readonly DeliveryRepository $deliveryRepository,
    ) {
    }

    #[Route('', name: 'api_admin_delivery_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $deliveries = $this->deliveryRepository->findAllOrderedByCreatedAtDesc();

        return $this->json(
            array_map(
                static fn ($delivery) => DeliveryResponse::fromEntity($delivery),
                $deliveries
            )
        );
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
