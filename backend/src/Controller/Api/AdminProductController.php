<?php

namespace App\Controller\Api;

use App\Dto\Admin\CreateProductRequest;
use App\Dto\Admin\ProductResponse;
use App\Dto\Admin\UpdateProductAvailabilityRequest;
use App\Dto\Admin\UpdateProductRequest;
use App\Exception\InvalidOperationException;
use App\Service\ProductService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/admin')]
#[IsGranted('ROLE_ADMIN')]
final class AdminProductController extends AbstractApiController
{
    use PaginationParamsTrait;

    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly ProductService $productService,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route(
        '/restaurants/{restaurantId}/products',
        name: 'api_admin_product_create',
        methods: ['POST']
    )]
    public function create(
        int $restaurantId,
        Request $request,
    ): JsonResponse {
        $restaurant = $this->productService->getRestaurant($restaurantId);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var CreateProductRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateProductRequest::class);

        $product = $this->productService->create(
            $restaurant,
            $dto
        );

        return $this->json(
            ProductResponse::fromEntity($product),
            Response::HTTP_CREATED
        );
    }

    #[Route(
        '/restaurants/{restaurantId}/products',
        name: 'api_admin_product_list',
        methods: ['GET']
    )]
    public function list(int $restaurantId, Request $request): JsonResponse
    {
        $restaurant = $this->productService->getRestaurant($restaurantId);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $result = $this->productService->listForRestaurant(
            $restaurant,
            $this->paginationPage($request),
            $this->paginationLimit($request)
        );

        return $this->paginatedJson($result, static fn ($product) => ProductResponse::fromEntity($product));
    }

    #[Route(
        '/products/{id}',
        name: 'api_admin_product_show',
        methods: ['GET']
    )]
    public function show(int $id): JsonResponse
    {
        $product = $this->productService->get($id);

        if (null === $product) {
            return $this->json(
                ['message' => 'Product not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(
            ProductResponse::fromEntity($product)
        );
    }

    #[Route(
        '/products/{id}',
        name: 'api_admin_product_update',
        methods: ['PUT']
    )]
    public function update(
        int $id,
        Request $request,
    ): JsonResponse {
        $product = $this->productService->get($id);

        if (null === $product) {
            return $this->json(
                ['message' => 'Product not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var UpdateProductRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateProductRequest::class);

        $product = $this->productService->update(
            $product,
            $dto
        );

        return $this->json(
            ProductResponse::fromEntity($product)
        );
    }

    #[Route(
        '/products/{id}/availability',
        name: 'api_admin_product_availability',
        methods: ['PATCH']
    )]
    public function availability(
        int $id,
        Request $request,
    ): JsonResponse {
        $product = $this->productService->get($id);

        if (null === $product) {
            return $this->json(
                ['message' => 'Product not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var UpdateProductAvailabilityRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateProductAvailabilityRequest::class);

        $product = $this->productService->setAvailability(
            $product,
            $dto->isAvailable
        );

        return $this->json(
            ProductResponse::fromEntity($product)
        );
    }

    #[Route(
        '/products/{id}',
        name: 'api_admin_product_delete',
        methods: ['DELETE']
    )]
    public function delete(int $id): JsonResponse
    {
        $product = $this->productService->get($id);

        if (null === $product) {
            return $this->json(
                ['message' => 'Product not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $this->productService->delete($product);

        return $this->json(null, Response::HTTP_NO_CONTENT);
    }

    #[Route(
        '/products/{id}/photo',
        name: 'api_admin_product_photo_upload',
        methods: ['POST']
    )]
    public function uploadPhoto(
        int $id,
        Request $request,
    ): JsonResponse {
        $product = $this->productService->get($id);

        if (null === $product) {
            return $this->json(
                ['message' => 'Product not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $file = $request->files->get('photo');

        if (null === $file) {
            throw new InvalidOperationException('No photo was uploaded.');
        }

        $product = $this->productService->setPhoto($product, $file);

        return $this->json(ProductResponse::fromEntity($product));
    }

    #[Route(
        '/products/{id}/photo',
        name: 'api_admin_product_photo_remove',
        methods: ['DELETE']
    )]
    public function removePhoto(int $id): JsonResponse
    {
        $product = $this->productService->get($id);

        if (null === $product) {
            return $this->json(
                ['message' => 'Product not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $product = $this->productService->removePhoto($product);

        return $this->json(ProductResponse::fromEntity($product));
    }
}
