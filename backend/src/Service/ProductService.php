<?php

namespace App\Service;

use App\Dto\Admin\CreateProductRequest;
use App\Dto\Admin\UpdateProductRequest;
use App\Entity\Category;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Repository\CategoryRepository;
use App\Repository\ProductRepository;
use Doctrine\ORM\EntityManagerInterface;

final class ProductService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly ProductRepository $productRepository,
        private readonly CategoryRepository $categoryRepository,
    ) {
    }

    public function create(
        Restaurant $restaurant,
        CreateProductRequest $dto
    ): Product {
        $category = $this->getCategoryForRestaurant(
            $dto->categoryId,
            $restaurant
        );

        $product = new Product();

        $product
            ->setName(trim((string) $dto->name))
            ->setDescription(
                null === $dto->description
                    ? null
                    : trim($dto->description)
            )
            ->setPrice($dto->price)
            ->setIsAvailable($dto->isAvailable)
            ->setRestaurant($restaurant)
            ->setCategory($category);

        $this->entityManager->persist($product);
        $this->entityManager->flush();

        return $product;
    }

    /**
     * @return Product[]
     */
    public function listForRestaurant(
        Restaurant $restaurant
    ): array {
        return $this->productRepository->findBy(
            ['restaurant' => $restaurant],
            ['createdAt' => 'ASC']
        );
    }

    public function get(int $id): ?Product
    {
        return $this->productRepository->find($id);
    }

    public function update(
        Product $product,
        UpdateProductRequest $dto
    ): Product {
        $restaurant = $product->getRestaurant();

        if (null === $restaurant) {
            throw new \RuntimeException(
                'Product is not associated with a restaurant.'
            );
        }

        $category = $this->getCategoryForRestaurant(
            $dto->categoryId,
            $restaurant
        );

        $product
            ->setName(trim((string) $dto->name))
            ->setDescription(
                null === $dto->description
                    ? null
                    : trim($dto->description)
            )
            ->setPrice($dto->price)
            ->setIsAvailable($dto->isAvailable)
            ->setCategory($category);

        $this->entityManager->flush();

        return $product;
    }

    public function setAvailability(
        Product $product,
        bool $isAvailable
    ): Product {
        $product->setIsAvailable($isAvailable);

        $this->entityManager->flush();

        return $product;
    }

    private function getCategoryForRestaurant(
        ?int $categoryId,
        Restaurant $restaurant
    ): Category {
        if (null === $categoryId) {
            throw new \RuntimeException(
                'Category is required.'
            );
        }

        $category = $this->categoryRepository->find($categoryId);

        if (null === $category) {
            throw new \RuntimeException(
                'Category not found.'
            );
        }

        if (
            $category->getRestaurant()?->getId()
            !== $restaurant->getId()
        ) {
            throw new \RuntimeException(
                'Category does not belong to this restaurant.'
            );
        }

        return $category;
    }
    public function getRestaurant(int $id): ?Restaurant
{
    return $this->entityManager
        ->getRepository(Restaurant::class)
        ->find($id);
}
}