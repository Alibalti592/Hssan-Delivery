<?php

namespace App\Service;

use App\Dto\Admin\CreateRestaurantRequest;
use App\Dto\Admin\UpdateRestaurantRequest;
use App\Entity\Restaurant;
use Doctrine\ORM\EntityManagerInterface;

final class RestaurantService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
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
}