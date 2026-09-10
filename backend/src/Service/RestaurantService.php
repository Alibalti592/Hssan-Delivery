<?php

namespace App\Service;

use App\Dto\Admin\CreateRestaurantRequest;
use App\Dto\Admin\UpdateRestaurantRequest;
use App\Entity\Restaurant;
use App\Exception\ConflictException;
use App\Repository\OrderRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\File\UploadedFile;

final class RestaurantService
{
    private const PHOTO_SUBDIRECTORY = 'restaurants';

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly OrderRepository $orderRepository,
        private readonly PhotoUploader $photoUploader,
    ) {
    }

    public function create(CreateRestaurantRequest $dto): Restaurant
    {
        $restaurant = new Restaurant();

        $restaurant
            ->setName($dto->name)
            ->setDescription($dto->description)
            ->setIsAvailable($dto->isAvailable);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        return $restaurant;
    }

    /**
     * @return Restaurant[]
     */
    public function list(): array
    {
        return $this->entityManager
            ->getRepository(Restaurant::class)
            ->findBy([], ['createdAt' => 'DESC']);
    }

    /**
     * The public catalogue: open restaurants only, alphabetical for browsing.
     *
     * @return Restaurant[]
     */
    public function listAvailable(): array
    {
        return $this->entityManager
            ->getRepository(Restaurant::class)
            ->findBy(['isAvailable' => true], ['name' => 'ASC']);
    }

    public function get(int $id): ?Restaurant
    {
        return $this->entityManager
            ->getRepository(Restaurant::class)
            ->find($id);
    }

    public function update(
        Restaurant $restaurant,
        UpdateRestaurantRequest $dto,
    ): Restaurant {
        $restaurant
            ->setName($dto->name)
            ->setDescription($dto->description)
            ->setIsAvailable($dto->isAvailable);

        $this->entityManager->flush();

        return $restaurant;
    }

    public function setAvailability(
        Restaurant $restaurant,
        bool $isAvailable,
    ): Restaurant {
        $restaurant->setIsAvailable($isAvailable);

        $this->entityManager->flush();

        return $restaurant;
    }

    /**
     * Deletes a restaurant along with its categories and products. Refuses
     * when the restaurant has any orders, since those reference it (and its
     * products) directly — deactivate it instead.
     */
    public function delete(Restaurant $restaurant): void
    {
        if ($this->orderRepository->count(['restaurant' => $restaurant]) > 0) {
            throw new ConflictException('This restaurant has existing orders and cannot be deleted. Deactivate it instead.');
        }

        foreach ($restaurant->getProducts() as $product) {
            $this->photoUploader->delete($product->getPhotoFilename(), 'products');
            $this->entityManager->remove($product);
        }

        foreach ($restaurant->getCategories() as $category) {
            $this->entityManager->remove($category);
        }

        $this->photoUploader->delete($restaurant->getPhotoFilename(), self::PHOTO_SUBDIRECTORY);

        $this->entityManager->remove($restaurant);
        $this->entityManager->flush();
    }

    public function setPhoto(Restaurant $restaurant, UploadedFile $file): Restaurant
    {
        $filename = $this->photoUploader->store($file, self::PHOTO_SUBDIRECTORY);

        $this->photoUploader->delete($restaurant->getPhotoFilename(), self::PHOTO_SUBDIRECTORY);

        $restaurant->setPhotoFilename($filename);

        $this->entityManager->flush();

        return $restaurant;
    }

    public function removePhoto(Restaurant $restaurant): Restaurant
    {
        $this->photoUploader->delete($restaurant->getPhotoFilename(), self::PHOTO_SUBDIRECTORY);

        $restaurant->setPhotoFilename(null);

        $this->entityManager->flush();

        return $restaurant;
    }
}
