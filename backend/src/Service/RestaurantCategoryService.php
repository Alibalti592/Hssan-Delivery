<?php

namespace App\Service;

use App\Dto\Admin\RestaurantCategoryRequest;
use App\Entity\RestaurantCategory;
use App\Enum\RestaurantType;
use App\Exception\ConflictException;
use App\Exception\ValidationFailedException;
use App\Repository\RestaurantCategoryRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\File\UploadedFile;

final class RestaurantCategoryService
{
    public const IMAGE_SUBDIRECTORY = 'restaurant-categories';

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly RestaurantCategoryRepository $restaurantCategoryRepository,
        private readonly PhotoUploader $photoUploader,
    ) {
    }

    /**
     * @return RestaurantCategory[]
     */
    public function list(): array
    {
        return $this->restaurantCategoryRepository->findAllOrdered();
    }

    /**
     * What the client can filter the restaurant (or grocery store) list by.
     *
     * @return RestaurantCategory[]
     */
    public function listInUse(RestaurantType $type): array
    {
        return $this->restaurantCategoryRepository->findInUse($type);
    }

    /**
     * @return array<int, int> restaurants per category id
     */
    public function restaurantCounts(): array
    {
        return $this->restaurantCategoryRepository->countRestaurantsByCategory();
    }

    public function get(int $id): ?RestaurantCategory
    {
        return $this->restaurantCategoryRepository->find($id);
    }

    /**
     * The categories behind a restaurant form's categoryIds.
     *
     * @param int[] $ids
     *
     * @return RestaurantCategory[]
     *
     * @throws ValidationFailedException when one of them doesn't exist
     */
    public function resolve(array $ids): array
    {
        $ids = array_values(array_unique($ids));

        if ([] === $ids) {
            return [];
        }

        $categories = $this->restaurantCategoryRepository->findBy(['id' => $ids]);

        if (count($categories) !== count($ids)) {
            throw new ValidationFailedException([['field' => 'categoryIds', 'message' => 'One of these categories does not exist.']]);
        }

        return $categories;
    }

    public function create(RestaurantCategoryRequest $dto): RestaurantCategory
    {
        $category = new RestaurantCategory();

        $this->apply($category, $dto);

        $this->entityManager->persist($category);
        $this->entityManager->flush();

        return $category;
    }

    public function update(RestaurantCategory $category, RestaurantCategoryRequest $dto): RestaurantCategory
    {
        $this->apply($category, $dto);

        $this->entityManager->flush();

        return $category;
    }

    /**
     * Its restaurants stay; they just lose this category.
     */
    public function delete(RestaurantCategory $category): void
    {
        $image = $category->getImageFilename();

        $this->entityManager->remove($category);
        $this->entityManager->flush();

        $this->photoUploader->delete($image, self::IMAGE_SUBDIRECTORY);
    }

    public function setImage(RestaurantCategory $category, UploadedFile $file): RestaurantCategory
    {
        $filename = $this->photoUploader->store($file, self::IMAGE_SUBDIRECTORY);

        $this->photoUploader->delete($category->getImageFilename(), self::IMAGE_SUBDIRECTORY);

        $category->setImageFilename($filename);

        $this->entityManager->flush();

        return $category;
    }

    public function removeImage(RestaurantCategory $category): RestaurantCategory
    {
        $this->photoUploader->delete($category->getImageFilename(), self::IMAGE_SUBDIRECTORY);

        $category->setImageFilename(null);

        $this->entityManager->flush();

        return $category;
    }

    private function apply(RestaurantCategory $category, RestaurantCategoryRequest $dto): void
    {
        $name = trim((string) $dto->name);

        $existing = $this->restaurantCategoryRepository->findOneBy(['name' => $name]);

        if (null !== $existing && $existing !== $category) {
            throw new ConflictException('A category with this name already exists.');
        }

        $category->setName($name);
        $category->setIcon($dto->icon);
        $category->setPosition((int) $dto->position);
    }
}
