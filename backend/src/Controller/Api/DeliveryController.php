<?php

namespace App\Controller\Api;

use App\Dto\DeliveryResponse;
use App\Entity\Delivery;
use App\Entity\User;
use App\Repository\DeliveryRepository;
use App\Repository\UserRepository;
use App\Service\DeliveryService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
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
        '/mine',
        name: 'api_delivery_mine',
        methods: ['GET']
    )]
    #[IsGranted('ROLE_LIVREUR')]
    public function mine(): JsonResponse
    {
        /** @var User $courier */
        $courier = $this->getUser();

        $deliveries = $this->deliveryRepository
            ->findByCourier($courier);

        return $this->json(
            array_map(
                fn ($delivery) => DeliveryResponse::fromEntity($delivery),
                $deliveries
            )
        );
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

        if (null === $delivery) {
            return $this->json(
                ['message' => 'Delivery not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $courier = $this->userRepository->find($courierId);

        if (null === $courier) {
            return $this->json(
                ['message' => 'Courier not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $delivery = $this->deliveryService->assignCourier(
            $delivery,
            $courier
        );

        return $this->json(
            DeliveryResponse::fromEntity($delivery)
        );
    }

    #[Route(
        '/{id}/accept',
        name: 'api_delivery_accept',
        methods: ['POST']
    )]
    #[IsGranted('ROLE_LIVREUR')]
    public function accept(int $id): JsonResponse
    {
        return $this->executeCourierTransition(
            $id,
            fn (Delivery $delivery, User $courier) => $this->deliveryService->acceptDelivery($delivery, $courier)
        );
    }

    #[Route(
        '/{id}/pickup',
        name: 'api_delivery_pickup',
        methods: ['POST']
    )]
    #[IsGranted('ROLE_LIVREUR')]
    public function pickup(int $id): JsonResponse
    {
        return $this->executeCourierTransition(
            $id,
            fn (Delivery $delivery, User $courier) => $this->deliveryService->markPickedUp($delivery, $courier)
        );
    }

    #[Route(
        '/{id}/on-the-way',
        name: 'api_delivery_on_the_way',
        methods: ['POST']
    )]
    #[IsGranted('ROLE_LIVREUR')]
    public function onTheWay(int $id): JsonResponse
    {
        return $this->executeCourierTransition(
            $id,
            fn (Delivery $delivery, User $courier) => $this->deliveryService->markOnTheWay($delivery, $courier)
        );
    }

    #[Route(
        '/{id}/delivered',
        name: 'api_delivery_delivered',
        methods: ['POST']
    )]
    #[IsGranted('ROLE_LIVREUR')]
    public function delivered(int $id): JsonResponse
    {
        return $this->executeCourierTransition(
            $id,
            fn (Delivery $delivery, User $courier) => $this->deliveryService->markDelivered($delivery, $courier)
        );
    }

    #[Route(
        '/{id}/cancel',
        name: 'api_delivery_cancel',
        methods: ['POST']
    )]
    #[IsGranted('ROLE_ADMIN')]
    public function cancel(int $id): JsonResponse
    {
        $delivery = $this->deliveryRepository->find($id);

        if (null === $delivery) {
            return $this->json(
                ['message' => 'Delivery not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $delivery = $this->deliveryService
            ->cancelDelivery($delivery);

        return $this->json(
            DeliveryResponse::fromEntity($delivery)
        );
    }

    #[Route(
        '/{id}/fail',
        name: 'api_delivery_fail',
        methods: ['POST']
    )]
    #[IsGranted('ROLE_LIVREUR')]
    public function fail(int $id): JsonResponse
    {
        return $this->executeCourierTransition(
            $id,
            fn (Delivery $delivery, User $courier) => $this->deliveryService->failDelivery($delivery, $courier)
        );
    }

    /**
     * @param callable(Delivery, User): Delivery $transition
     */
    private function executeCourierTransition(
        int $id,
        callable $transition,
    ): JsonResponse {
        $delivery = $this->deliveryRepository->find($id);

        if (null === $delivery) {
            return $this->json(
                ['message' => 'Delivery not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var User $courier */
        $courier = $this->getUser();

        $delivery = $transition($delivery, $courier);

        return $this->json(
            DeliveryResponse::fromEntity($delivery)
        );
    }
}
