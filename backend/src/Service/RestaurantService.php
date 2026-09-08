<?php

namespace App\Service;

use App\Dto\Admin\CreateRestaurantRequest;
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

    public function list(): array
    {
        return $this->entityManager
            ->getRepository(Restaurant::class)
            ->findBy([], ['createdAt' => 'DESC']);
    }
}
