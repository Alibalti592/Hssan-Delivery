<?php

namespace App\Controller\Api;

use App\Dto\Admin\RestaurantCategoryRequest;
use App\Dto\Admin\RestaurantCategoryResponse;
use App\Exception\InvalidOperationException;
use App\Service\RestaurantCategoryService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

/**
 * The categories restaurants are browsed by in the app ("Pizza",
 * "Sucré"...). Which restaurant has which is set on the restaurant itself
 * (see AdminRestaurantController, categoryIds).
 */
#[Route('/api/admin/restaurant-categories')]
#[IsGranted('ROLE_ADMIN')]
final class AdminRestaurantCategoryController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly RestaurantCategoryService $restaurantCategoryService,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_admin_restaurant_category_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $counts = $this->restaurantCategoryService->restaurantCounts();

        return $this->json(array_map(
            static fn ($category) => RestaurantCategoryResponse::fromEntity($category) + [
                'restaurantCount' => $counts[$category->getId()] ?? 0,
            ],
            $this->restaurantCategoryService->list()
        ));
    }

    #[Route('', name: 'api_admin_restaurant_category_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        /** @var RestaurantCategoryRequest $dto */
        $dto = $this->deserializeAndValidate($request, RestaurantCategoryRequest::class);

        return $this->json(
            RestaurantCategoryResponse::fromEntity($this->restaurantCategoryService->create($dto)),
            Response::HTTP_CREATED
        );
    }

    #[Route('/{id}', name: 'api_admin_restaurant_category_update', methods: ['PUT'])]
    public function update(int $id, Request $request): JsonResponse
    {
        $category = $this->restaurantCategoryService->get($id);

        if (null === $category) {
            return $this->categoryNotFound();
        }

        /** @var RestaurantCategoryRequest $dto */
        $dto = $this->deserializeAndValidate($request, RestaurantCategoryRequest::class);

        return $this->json(
            RestaurantCategoryResponse::fromEntity($this->restaurantCategoryService->update($category, $dto))
        );
    }

    #[Route('/{id}', name: 'api_admin_restaurant_category_delete', methods: ['DELETE'])]
    public function delete(int $id): JsonResponse
    {
        $category = $this->restaurantCategoryService->get($id);

        if (null === $category) {
            return $this->categoryNotFound();
        }

        $this->restaurantCategoryService->delete($category);

        return $this->json(null, Response::HTTP_NO_CONTENT);
    }

    #[Route('/{id}/image', name: 'api_admin_restaurant_category_image_upload', methods: ['POST'])]
    public function uploadImage(int $id, Request $request): JsonResponse
    {
        $category = $this->restaurantCategoryService->get($id);

        if (null === $category) {
            return $this->categoryNotFound();
        }

        $file = $request->files->get('image');

        if (null === $file) {
            throw new InvalidOperationException('No image was uploaded.');
        }

        return $this->json(
            RestaurantCategoryResponse::fromEntity($this->restaurantCategoryService->setImage($category, $file))
        );
    }

    #[Route('/{id}/image', name: 'api_admin_restaurant_category_image_remove', methods: ['DELETE'])]
    public function removeImage(int $id): JsonResponse
    {
        $category = $this->restaurantCategoryService->get($id);

        if (null === $category) {
            return $this->categoryNotFound();
        }

        return $this->json(
            RestaurantCategoryResponse::fromEntity($this->restaurantCategoryService->removeImage($category))
        );
    }

    private function categoryNotFound(): JsonResponse
    {
        return $this->json(
            ['message' => 'Restaurant category not found.'],
            Response::HTTP_NOT_FOUND
        );
    }
}
