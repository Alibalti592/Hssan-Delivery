<?php

namespace App\Controller\Api;

use App\Dto\Admin\CreateRestaurantRequest;
use App\Dto\Admin\UpdateRestaurantAvailabilityRequest;
use App\Dto\Admin\UpdateRestaurantRequest;
use App\Service\RestaurantService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/admin/restaurants')]
#[IsGranted('ROLE_ADMIN')]
final class AdminRestaurantController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly RestaurantService $restaurantService,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_admin_restaurant_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        /** @var CreateRestaurantRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateRestaurantRequest::class);

        $restaurant = $this->restaurantService->create($dto);

        return $this->json(
            [
                'id' => $restaurant->getId(),
                'name' => $restaurant->getName(),
                'description' => $restaurant->getDescription(),
                'isAvailable' => $restaurant->isAvailable(),
                'createdAt' => $restaurant->getCreatedAt()?->format(
                    \DateTimeInterface::ATOM
                ),
                'updatedAt' => $restaurant->getUpdatedAt()?->format(
                    \DateTimeInterface::ATOM
                ),
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
                    'createdAt' => $restaurant->getCreatedAt()?->format(
                        \DateTimeInterface::ATOM
                    ),
                    'updatedAt' => $restaurant->getUpdatedAt()?->format(
                        \DateTimeInterface::ATOM
                    ),
                ],
                $restaurants
            )
        );
    }

    #[Route('/{id}', name: 'api_admin_restaurant_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $restaurant = $this->restaurantService->get($id);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json([
            'id' => $restaurant->getId(),
            'name' => $restaurant->getName(),
            'description' => $restaurant->getDescription(),
            'isAvailable' => $restaurant->isAvailable(),
            'createdAt' => $restaurant->getCreatedAt()?->format(
                \DateTimeInterface::ATOM
            ),
            'updatedAt' => $restaurant->getUpdatedAt()?->format(
                \DateTimeInterface::ATOM
            ),
        ]);
    }

    #[Route('/{id}', name: 'api_admin_restaurant_update', methods: ['PUT'])]
    public function update(
        int $id,
        Request $request,
    ): JsonResponse {
        $restaurant = $this->restaurantService->get($id);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var UpdateRestaurantRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateRestaurantRequest::class);

        $restaurant = $this->restaurantService->update(
            $restaurant,
            $dto
        );

        return $this->json([
            'id' => $restaurant->getId(),
            'name' => $restaurant->getName(),
            'description' => $restaurant->getDescription(),
            'isAvailable' => $restaurant->isAvailable(),
            'createdAt' => $restaurant->getCreatedAt()?->format(
                \DateTimeInterface::ATOM
            ),
            'updatedAt' => $restaurant->getUpdatedAt()?->format(
                \DateTimeInterface::ATOM
            ),
        ]);
    }

    #[Route(
        '/{id}/availability',
        name: 'api_admin_restaurant_availability',
        methods: ['PATCH']
    )]
    public function availability(
        int $id,
        Request $request,
    ): JsonResponse {
        $restaurant = $this->restaurantService->get($id);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var UpdateRestaurantAvailabilityRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateRestaurantAvailabilityRequest::class);

        $restaurant = $this->restaurantService->setAvailability(
            $restaurant,
            $dto->isAvailable
        );

        return $this->json([
            'id' => $restaurant->getId(),
            'name' => $restaurant->getName(),
            'description' => $restaurant->getDescription(),
            'isAvailable' => $restaurant->isAvailable(),
            'createdAt' => $restaurant->getCreatedAt()?->format(
                \DateTimeInterface::ATOM
            ),
            'updatedAt' => $restaurant->getUpdatedAt()?->format(
                \DateTimeInterface::ATOM
            ),
        ]);
    }
}
