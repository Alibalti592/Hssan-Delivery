<?php

namespace App\Controller\Api;

use App\Dto\Admin\CreateDeliveryZoneRequest;
use App\Dto\Admin\DeliveryZoneResponse;
use App\Dto\Admin\UpdateDeliveryZoneRequest;
use App\Service\DeliveryZoneService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/admin/delivery-zones')]
#[IsGranted('ROLE_ADMIN')]
final class AdminDeliveryZoneController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly DeliveryZoneService $deliveryZoneService,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_admin_delivery_zone_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        /** @var CreateDeliveryZoneRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateDeliveryZoneRequest::class);

        try {
            $zone = $this->deliveryZoneService->create($dto);
        } catch (\RuntimeException $exception) {
            return $this->json(
                ['message' => $exception->getMessage()],
                Response::HTTP_CONFLICT
            );
        }

        return $this->json(
            DeliveryZoneResponse::fromEntity($zone),
            Response::HTTP_CREATED
        );
    }

    #[Route('', name: 'api_admin_delivery_zone_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $zones = $this->deliveryZoneService->list();

        return $this->json(
            array_map(
                static fn ($zone) => DeliveryZoneResponse::fromEntity($zone),
                $zones
            )
        );
    }

    #[Route('/{id}', name: 'api_admin_delivery_zone_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $zone = $this->deliveryZoneService->get($id);

        if (null === $zone) {
            return $this->json(
                ['message' => 'Delivery zone not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(
            DeliveryZoneResponse::fromEntity($zone)
        );
    }

    #[Route('/{id}', name: 'api_admin_delivery_zone_update', methods: ['PUT'])]
    public function update(
        int $id,
        Request $request,
    ): JsonResponse {
        $zone = $this->deliveryZoneService->get($id);

        if (null === $zone) {
            return $this->json(
                ['message' => 'Delivery zone not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var UpdateDeliveryZoneRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateDeliveryZoneRequest::class);

        try {
            $zone = $this->deliveryZoneService->update($zone, $dto);
        } catch (\RuntimeException $exception) {
            return $this->json(
                ['message' => $exception->getMessage()],
                Response::HTTP_CONFLICT
            );
        }

        return $this->json(
            DeliveryZoneResponse::fromEntity($zone)
        );
    }
}
