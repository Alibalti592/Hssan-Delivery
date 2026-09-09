<?php

namespace App\Controller\Api;

use App\Dto\DeliveryZoneResponse;
use App\Repository\DeliveryZoneRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/delivery-zones')]
final class DeliveryZoneController extends AbstractController
{
    public function __construct(
        private readonly DeliveryZoneRepository $deliveryZoneRepository,
    ) {
    }

    #[Route('', name: 'api_delivery_zones_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $zones = $this->deliveryZoneRepository->findAllOrderedByName();

        return $this->json(
            array_map(
                static fn ($zone) => DeliveryZoneResponse::fromEntity($zone),
                $zones
            )
        );
    }
}
