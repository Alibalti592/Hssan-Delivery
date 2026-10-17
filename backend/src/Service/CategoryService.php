<?php

namespace App\Service;

use App\Dto\Admin\CreateCategoryRequest;
use App\Dto\Admin\UpdateCategoryRequest;
use App\Entity\Category;
use App\Entity\Restaurant;
use App\Exception\ConflictException;
use App\Repository\CategoryRepository;
use App\Repository\RestaurantRepository;
use Doctrine\ORM\EntityManagerInterface;

final class CategoryService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly CategoryRepository $categoryRepository,
        private readonly RestaurantRepository $restaurantRepository,
    ) {
    }

    public function create(
        Restaurant $restaurant,
        CreateCategoryRequest $dto,
    ): Category {
        $category = new Category();

        $category
            ->setName(trim((string) $dto->name))
            ->setRestaurant($restaurant);

        $this->entityManager->persist($category);
        $this->entityManager->flush();

        return $category;
    }

    /**
     * @return Category[]
     */
    public function listForRestaurant(Restaurant $restaurant): array
    {
        return $this->categoryRepository->findBy(
            ['restaurant' => $restaurant],
            ['createdAt' => 'ASC']
        );
    }

    public function get(int $id): ?Category
    {
        return $this->categoryRepository->find($id);
    }

    public function update(
        Category $category,
        UpdateCategoryRequest $dto,
    ): Category {
        $category->setName(
            trim((string) $dto->name)
        );

        $this->entityManager->flush();

        return $category;
    }

    /**
     * Removes an empty category. One that still holds products is refused,
     * so no product is deleted or left without a category by accident.
     */
    public function delete(Category $category): void
    {
        if (!$category->getProducts()->isEmpty()) {
            throw new ConflictException('Move or delete its products first: this category still holds some.');
        }

        $this->entityManager->remove($category);
        $this->entityManager->flush();
    }

    public function getRestaurant(int $id): ?Restaurant
    {
        return $this->restaurantRepository->find($id);
    }
}
