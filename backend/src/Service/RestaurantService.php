<?php

namespace App\Service;

use App\Dto\Admin\CreateRestaurantRequest;
use App\Dto\Admin\UpdateRestaurantRequest;
use App\Entity\Restaurant;
use App\Repository\RestaurantRepository;
use Doctrine\ORM\EntityManagerInterface;

final class RestaurantService
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly RestaurantRepository $restaurantRepository,
    ) {
    }

    public function create(CreateRestaurantRequest $dto): Restaurant
    {
        $restaurant = new Restaurant();

        $restaurant
            ->setName(trim($dto->name))
            ->setDescription(
                null === $dto->description
                    ? null
                    : trim($dto->description)
            )
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
        return $this->restaurantRepository->findBy(
            [],
            ['createdAt' => 'DESC']
        );
    }

    public function get(int $id): ?Restaurant
    {
        return $this->restaurantRepository->find($id);
    }

    public function update(
        Restaurant $restaurant,
        UpdateRestaurantRequest $dto
    ): Restaurant {
        $restaurant
            ->setName(trim($dto->name))
            ->setDescription(
                null === $dto->description
                    ? null
                    : trim($dto->description)
            )
            ->setIsAvailable($dto->isAvailable);

        $this->entityManager->flush();

        return $restaurant;
    }

    public function setAvailability(
        Restaurant $restaurant,
        bool $isAvailable
    ): Restaurant {
        $restaurant->setIsAvailable($isAvailable);

        $this->entityManager->flush();

        return $restaurant;
    }
}