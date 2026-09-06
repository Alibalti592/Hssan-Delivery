<?php

namespace App\Controller\Api;

use App\Repository\DeliveryRepository;
use App\Repository\UserRepository;
use App\Service\DeliveryService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/api/deliveries')]
final class DeliveryController extends AbstractController
{
    public function __construct(
        private readonly DeliveryService $deliveryService,
        private readonly DeliveryRepository $deliveryRepository,
        private readonly UserRepository $userRepository,
    ) {
    }

    #[Route(
        '/{id}/assign/{courierId}',
        name: 'api_delivery_assign',
        methods: ['POST']
    )]
    #[IsGranted('ROLE_ADMIN')]
    public function assign(
        int $id,
        int $courierId,
    ): JsonResponse {
        $delivery = $this->deliveryRepository->find($id);

        if ($delivery === null) {
            return $this->json(
                ['message' => 'Delivery not found.'],
                404
            );
        }

        $courier = $this->userRepository->find($courierId);

        if ($courier === null) {
            return $this->json(
                ['message' => 'Courier not found.'],
                404
            );
        }

        try {
            $delivery = $this->deliveryService->assignCourier(
                $delivery,
                $courier
            );

            return $this->json([
                'id' => $delivery->getId(),
                'status' => $delivery->getStatus()->value,
                'courierId' => $delivery->getCourier()?->getId(),
                'assignedAt' => $delivery->getAssignedAt()?->format(
                    \DateTimeInterface::ATOM
                ),
            ]);
        } catch (\RuntimeException $exception) {
            return $this->json(
                ['message' => $exception->getMessage()],
                400
            );
        }
    }
}