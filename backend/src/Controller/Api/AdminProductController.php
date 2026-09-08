<?php

namespace App\Controller\Api;

use App\Dto\Admin\CreateProductRequest;
use App\Dto\Admin\ProductResponse;
use App\Dto\Admin\UpdateProductAvailabilityRequest;
use App\Dto\Admin\UpdateProductRequest;
use App\Service\ProductService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/admin')]
#[IsGranted('ROLE_ADMIN')]
final class AdminProductController extends AbstractController
{
    public function __construct(
        private readonly SerializerInterface $serializer,
        private readonly ValidatorInterface $validator,
        private readonly ProductService $productService,
    ) {
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
        $dto = $this->serializer->deserialize(
            $request->getContent(),
            CreateProductRequest::class,
            'json'
        );

        $violations = $this->validator->validate($dto);

        if (count($violations) > 0) {
            return $this->json(
                [
                    'message' => 'Validation failed.',
                    'errors' => array_map(
                        static fn ($violation) => [
                            'field' => $violation->getPropertyPath(),
                            'message' => $violation->getMessage(),
                        ],
                        iterator_to_array($violations)
                    ),
                ],
                Response::HTTP_UNPROCESSABLE_ENTITY
            );
        }

        try {
            $product = $this->productService->create(
                $restaurant,
                $dto
            );
        } catch (\RuntimeException $exception) {
            return $this->json(
                ['message' => $exception->getMessage()],
                Response::HTTP_BAD_REQUEST
            );
        }

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
    public function list(int $restaurantId): JsonResponse
    {
        $restaurant = $this->productService->getRestaurant($restaurantId);

        if (null === $restaurant) {
            return $this->json(
                ['message' => 'Restaurant not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $products = $this->productService->listForRestaurant(
            $restaurant
        );

        return $this->json(
            array_map(
                static fn ($product) =>
                    ProductResponse::fromEntity($product),
                $products
            )
        );
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
        $dto = $this->serializer->deserialize(
            $request->getContent(),
            UpdateProductRequest::class,
            'json'
        );

        $violations = $this->validator->validate($dto);

        if (count($violations) > 0) {
            return $this->json(
                [
                    'message' => 'Validation failed.',
                    'errors' => array_map(
                        static fn ($violation) => [
                            'field' => $violation->getPropertyPath(),
                            'message' => $violation->getMessage(),
                        ],
                        iterator_to_array($violations)
                    ),
                ],
                Response::HTTP_UNPROCESSABLE_ENTITY
            );
        }

        try {
            $product = $this->productService->update(
                $product,
                $dto
            );
        } catch (\RuntimeException $exception) {
            return $this->json(
                ['message' => $exception->getMessage()],
                Response::HTTP_BAD_REQUEST
            );
        }

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
        $dto = $this->serializer->deserialize(
            $request->getContent(),
            UpdateProductAvailabilityRequest::class,
            'json'
        );

        $violations = $this->validator->validate($dto);

        if (count($violations) > 0) {
            return $this->json(
                [
                    'message' => 'Validation failed.',
                    'errors' => array_map(
                        static fn ($violation) => [
                            'field' => $violation->getPropertyPath(),
                            'message' => $violation->getMessage(),
                        ],
                        iterator_to_array($violations)
                    ),
                ],
                Response::HTTP_UNPROCESSABLE_ENTITY
            );
        }

        $product = $this->productService->setAvailability(
            $product,
            $dto->isAvailable
        );

        return $this->json(
            ProductResponse::fromEntity($product)
        );
    }
}