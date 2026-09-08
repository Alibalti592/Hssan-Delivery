<?php

namespace App\Controller\Api;

use App\Dto\Admin\CategoryResponse;
use App\Dto\Admin\CreateCategoryRequest;
use App\Dto\Admin\UpdateCategoryRequest;
use App\Service\CategoryService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/admin')]
#[IsGranted('ROLE_ADMIN')]
final class AdminCategoryController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly CategoryService $categoryService,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route(
        '/restaurants/{restaurantId}/categories',
        name: 'api_admin_category_create',
        methods: ['POST']
    )]
    public function create(
        int $restaurantId,
        Request $request,
    ): JsonResponse {
        $restaurant = $this->categoryService->getRestaurant($restaurantId);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var CreateCategoryRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateCategoryRequest::class);

        $category = $this->categoryService->create(
            $restaurant,
            $dto
        );

        return $this->json(
            CategoryResponse::fromEntity($category),
            Response::HTTP_CREATED
        );
    }

    #[Route(
        '/restaurants/{restaurantId}/categories',
        name: 'api_admin_category_list',
        methods: ['GET']
    )]
    public function list(int $restaurantId): JsonResponse
    {
        $restaurant = $this->categoryService->getRestaurant($restaurantId);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $categories = $this->categoryService->listForRestaurant(
            $restaurant
        );

        return $this->json(
            array_map(
                static fn ($category) => CategoryResponse::fromEntity($category),
                $categories
            )
        );
    }

    #[Route(
        '/categories/{id}',
        name: 'api_admin_category_show',
        methods: ['GET']
    )]
    public function show(int $id): JsonResponse
    {
        $category = $this->categoryService->get($id);

        if (null === $category) {
            return $this->json(
                ['message' => 'Category not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(
            CategoryResponse::fromEntity($category)
        );
    }

    #[Route(
        '/categories/{id}',
        name: 'api_admin_category_update',
        methods: ['PUT']
    )]
    public function update(
        int $id,
        Request $request,
    ): JsonResponse {
        $category = $this->categoryService->get($id);

        if (null === $category) {
            return $this->json(
                ['message' => 'Category not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var UpdateCategoryRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateCategoryRequest::class);

        $category = $this->categoryService->update(
            $category,
            $dto
        );

        return $this->json(
            CategoryResponse::fromEntity($category)
        );
    }
}
