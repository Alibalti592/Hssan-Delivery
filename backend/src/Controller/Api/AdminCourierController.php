<?php

namespace App\Controller\Api;

use App\Dto\Admin\CreateCourierRequest;
use App\Service\AuthService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/admin/couriers')]
#[IsGranted('ROLE_ADMIN')]
final class AdminCourierController extends AbstractController
{
    public function __construct(
        private readonly SerializerInterface $serializer,
        private readonly ValidatorInterface $validator,
        private readonly AuthService $authService,
    ) {
    }

    #[Route('', name: 'api_admin_courier_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        /** @var CreateCourierRequest $dto */
        $dto = $this->serializer->deserialize(
            $request->getContent(),
            CreateCourierRequest::class,
            'json'
        );

        $violations = $this->validator->validate($dto);

        if (count($violations) > 0) {
            $errors = [];

            foreach ($violations as $violation) {
                $errors[] = [
                    'field' => $violation->getPropertyPath(),
                    'message' => $violation->getMessage(),
                ];
            }

            return $this->json(
                [
                    'message' => 'Validation failed.',
                    'errors' => $errors,
                ],
                Response::HTTP_UNPROCESSABLE_ENTITY
            );
        }

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
