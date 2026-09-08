<?php

namespace App\Controller\Api;

use App\Dto\Admin\CreateRestaurantRequest;
use App\Service\RestaurantService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/admin/restaurants')]
#[IsGranted('ROLE_ADMIN')]
final class AdminRestaurantController extends AbstractController
{
    public function __construct(
        private readonly SerializerInterface $serializer,
        private readonly ValidatorInterface $validator,
        private readonly RestaurantService $restaurantService,
    ) {
    }

    #[Route('', name: 'api_admin_restaurant_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        /** @var CreateRestaurantRequest $dto */
        $dto = $this->serializer->deserialize(
            $request->getContent(),
            CreateRestaurantRequest::class,
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

        $restaurant = $this->restaurantService->create($dto);

        return $this->json(
            [
                'id' => $restaurant->getId(),
                'name' => $restaurant->getName(),
                'description' => $restaurant->getDescription(),
                'isAvailable' => $restaurant->isAvailable(),
                'createdAt' => $restaurant->getCreatedAt()?->format(\DateTimeInterface::ATOM),
                'updatedAt' => $restaurant->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
            ],
            Response::HTTP_CREATED
        );
    }

    #[Route('', name: 'api_admin_restaurant_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $restaurants = $this->restaurantService->list();

        return $this->json(
            array_map(
                static fn ($restaurant) => [
                    'id' => $restaurant->getId(),
                    'name' => $restaurant->getName(),
                    'description' => $restaurant->getDescription(),
                    'isAvailable' => $restaurant->isAvailable(),
                    'createdAt' => $restaurant->getCreatedAt()?->format(\DateTimeInterface::ATOM),
                    'updatedAt' => $restaurant->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
                ],
                $restaurants
            )
        );
    }
}
