<?php

namespace App\Controller\Api;

use App\Dto\Admin\CreateRestaurantRequest;
use App\Dto\Admin\RestaurantResponse;
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
        private readonly RestaurantService $restaurantService,
        private readonly SerializerInterface $serializer,
        private readonly ValidatorInterface $validator,
    ) {
    }

    #[Route('', name: 'api_admin_restaurants_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $restaurants = $this->restaurantService->list();

        return $this->json(
            array_map(
                static fn ($restaurant) => RestaurantResponse::fromEntity($restaurant),
                $restaurants
            )
        );
    }

    #[Route('', name: 'api_admin_restaurants_create', methods: ['POST'])]
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
            return $this->validationErrorResponse($violations);
        }

        $restaurant = $this->restaurantService->create($dto);

        return $this->json(
            RestaurantResponse::fromEntity($restaurant),
            Response::HTTP_CREATED
        );
    }

    #[Route('/{id}', name: 'api_admin_restaurants_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $restaurant = $this->restaurantService->get($id);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(
            RestaurantResponse::fromEntity($restaurant)
        );
    }

    #[Route('/{id}', name: 'api_admin_restaurants_update', methods: ['PUT'])]
    public function update(
        int $id,
        Request $request
    ): JsonResponse {
        $restaurant = $this->restaurantService->get($id);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var UpdateRestaurantRequest $dto */
        $dto = $this->serializer->deserialize(
            $request->getContent(),
            UpdateRestaurantRequest::class,
            'json'
        );

        $violations = $this->validator->validate($dto);

        if (count($violations) > 0) {
            return $this->validationErrorResponse($violations);
        }

        $restaurant = $this->restaurantService->update(
            $restaurant,
            $dto
        );

        return $this->json(
            RestaurantResponse::fromEntity($restaurant)
        );
    }

    #[Route(
        '/{id}/availability',
        name: 'api_admin_restaurants_availability',
        methods: ['PATCH']
    )]
    public function availability(
        int $id,
        Request $request
    ): JsonResponse {
        $restaurant = $this->restaurantService->get($id);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var UpdateRestaurantAvailabilityRequest $dto */
        $dto = $this->serializer->deserialize(
            $request->getContent(),
            UpdateRestaurantAvailabilityRequest::class,
            'json'
        );

        $violations = $this->validator->validate($dto);

        if (count($violations) > 0) {
            return $this->validationErrorResponse($violations);
        }

        $restaurant = $this->restaurantService->setAvailability(
            $restaurant,
            $dto->isAvailable
        );

        return $this->json(
            RestaurantResponse::fromEntity($restaurant)
        );
    }
}