<?php

namespace App\Service;

use App\Dto\Admin\CreateProductRequest;
use App\Dto\Admin\UpdateProductRequest;
use App\Entity\Category;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Exception\ConflictException;
use App\Exception\InvalidOperationException;
use App\Repository\CategoryRepository;
use App\Repository\OrderItemRepository;
use App\Repository\ProductRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\File\UploadedFile;

final class ProductService
{
    private const PHOTO_SUBDIRECTORY = 'products';

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly ProductRepository $productRepository,
        private readonly CategoryRepository $categoryRepository,
        private readonly OrderItemRepository $orderItemRepository,
        private readonly PhotoUploader $photoUploader,
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
            throw new InvalidOperationException(
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

    /**
     * Refuses when the product appears in any order, since order history
     * references it directly — deactivate it instead.
     */
    public function delete(Product $product): void
    {
        if ($this->orderItemRepository->count(['product' => $product]) > 0) {
            throw new ConflictException('This product has existing orders and cannot be deleted. Deactivate it instead.');
        }

        $this->photoUploader->delete($product->getPhotoFilename(), self::PHOTO_SUBDIRECTORY);

        $this->entityManager->remove($product);
        $this->entityManager->flush();
    }

    public function setPhoto(Product $product, UploadedFile $file): Product
    {
        $filename = $this->photoUploader->store($file, self::PHOTO_SUBDIRECTORY);

        $this->photoUploader->delete($product->getPhotoFilename(), self::PHOTO_SUBDIRECTORY);

        $product->setPhotoFilename($filename);

        $this->entityManager->flush();

        return $product;
    }

    public function removePhoto(Product $product): Product
    {
        $this->photoUploader->delete($product->getPhotoFilename(), self::PHOTO_SUBDIRECTORY);

        $product->setPhotoFilename(null);

        $this->entityManager->flush();

        return $product;
    }

    private function getCategoryForRestaurant(
        ?int $categoryId,
        Restaurant $restaurant
    ): Category {
        if (null === $categoryId) {
            throw new InvalidOperationException(
                'Category is required.'
            );
        }

        $category = $this->categoryRepository->find($categoryId);

        if (null === $category) {
            throw new InvalidOperationException(
                'Category not found.'
            );
        }

        if (
            $category->getRestaurant()?->getId()
            !== $restaurant->getId()
        ) {
            throw new InvalidOperationException(
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