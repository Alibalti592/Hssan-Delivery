<?php

namespace App\Controller\Api;

use App\Dto\Admin\CreateCourierRequest;
use App\Service\AuthService;
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
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_admin_courier_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        /** @var CreateCourierRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateCourierRequest::class);

        try {
            $courier = $this->authService->createCourier($dto);
        } catch (\RuntimeException $exception) {
            return $this->json(
                ['message' => $exception->getMessage()],
                Response::HTTP_CONFLICT
            );
        }

        return $this->json(
            [
                'id' => $courier->getId(),
                'name' => $courier->getName(),
                'phone' => $courier->getPhone(),
                'roles' => $courier->getRoles(),
                'verified' => $courier->isVerified(),
            ],
            Response::HTTP_CREATED
        );
    }
}
