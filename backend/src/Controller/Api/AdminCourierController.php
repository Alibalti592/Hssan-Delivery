<?php

namespace App\Controller\Api;

use App\Dto\Admin\CourierResponse;
use App\Dto\Admin\CreateCourierRequest;
use App\Dto\Admin\UpdateCourierActiveRequest;
use App\Service\AuthService;
use App\Service\CourierService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/admin/couriers')]
#[IsGranted('ROLE_ADMIN')]
final class AdminCourierController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly AuthService $authService,
        private readonly CourierService $courierService,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_admin_courier_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        /** @var CreateCourierRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateCourierRequest::class);

        $courier = $this->authService->createCourier($dto);

        return $this->json(
            CourierResponse::fromEntity($courier),
            Response::HTTP_CREATED
        );
    }

    #[Route('', name: 'api_admin_courier_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $couriers = $this->courierService->list();

        return $this->json(
            array_map(
                static fn ($courier) => CourierResponse::fromEntity($courier),
                $couriers
            )
        );
    }

    #[Route('/{id}', name: 'api_admin_courier_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $courier = $this->courierService->get($id);

        if (null === $courier) {
            return $this->json(
                ['message' => 'Courier not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(
            CourierResponse::fromEntity($courier)
        );
    }

    #[Route('/{id}/active', name: 'api_admin_courier_active', methods: ['PATCH'])]
    public function active(
        int $id,
        Request $request,
    ): JsonResponse {
        $courier = $this->courierService->get($id);

        if (null === $courier) {
            return $this->json(
                ['message' => 'Courier not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var UpdateCourierActiveRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateCourierActiveRequest::class);

        $courier = $this->courierService->setActive($courier, $dto->isActive);

        return $this->json(
            CourierResponse::fromEntity($courier)
        );
    }
}
