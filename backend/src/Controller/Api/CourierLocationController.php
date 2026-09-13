<?php

namespace App\Controller\Api;

use App\Dto\Admin\UpdateCourierLocationRequest;
use App\Service\CourierLocationService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

/**
 * Reports a signed-in courier's current GPS position. The mobile courier
 * app calls this periodically while active (see mobile CourierLocationService)
 * — it is not continuous background tracking, just a best-effort "here's
 * where I am right now" ping.
 */
#[Route('/api/couriers')]
#[IsGranted('ROLE_LIVREUR')]
final class CourierLocationController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly CourierLocationService $courierLocationService,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('/location', name: 'api_courier_location_update', methods: ['POST'])]
    public function update(Request $request): JsonResponse
    {
        /** @var UpdateCourierLocationRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateCourierLocationRequest::class);

        $this->courierLocationService->updateLocation($this->getUser(), $dto->latitude, $dto->longitude);

        return $this->json(null, Response::HTTP_NO_CONTENT);
    }
}
