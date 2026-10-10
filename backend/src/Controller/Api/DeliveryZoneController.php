<?php

namespace App\Controller\Api;

use App\Dto\DeliveryZoneResponse;
use App\Repository\DeliveryZoneRepository;
use App\Service\DeliveryZoneService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/delivery-zones')]
final class DeliveryZoneController extends AbstractController
{
    public function __construct(
        private readonly DeliveryZoneRepository $deliveryZoneRepository,
        private readonly DeliveryZoneService $deliveryZoneService,
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

    /**
     * The zone covering an address pin (?latitude=…&longitude=…), so the
     * app fills it in by itself. 404 when no zone placed on the map covers
     * it: the client then picks one.
     */
    #[Route('/locate', name: 'api_delivery_zones_locate', methods: ['GET'])]
    public function locate(Request $request): JsonResponse
    {
        $latitude = filter_var($request->query->get('latitude'), FILTER_VALIDATE_FLOAT);
        $longitude = filter_var($request->query->get('longitude'), FILTER_VALIDATE_FLOAT);

        if (false === $latitude || false === $longitude
            || abs($latitude) > 90 || abs($longitude) > 180) {
            return $this->json(['message' => 'Position invalide.'], Response::HTTP_BAD_REQUEST);
        }

        $zone = $this->deliveryZoneService->locate($latitude, $longitude);

        if (null === $zone) {
            return $this->json(
                ['message' => DeliveryZoneService::OUTSIDE_ZONES],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(DeliveryZoneResponse::fromEntity($zone));
    }
}
