<?php

namespace App\Service;

use App\Dto\Admin\CreateRestaurantRequest;
use App\Dto\Admin\UpdateRestaurantRequest;
use App\Entity\Restaurant;
use App\Enum\RestaurantType;
use App\Exception\ConflictException;
use App\Pagination\PaginatedResult;
use App\Pagination\Paginator;
use App\Repository\OrderRepository;
use App\Repository\PromotionRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\File\UploadedFile;

final class RestaurantService
{
    private const PHOTO_SUBDIRECTORY = 'restaurants';

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly OrderRepository $orderRepository,
        private readonly PromotionRepository $promotionRepository,
        private readonly PhotoUploader $photoUploader,
    ) {
    }

    public function create(CreateRestaurantRequest $dto): Restaurant
    {
        $restaurant = new Restaurant();

        $restaurant
            ->setName($dto->name)
            ->setDescription($dto->description)
            ->setIsAvailable($dto->isAvailable)
            ->setType(RestaurantType::from($dto->type));

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        return $restaurant;
    }

    /**
     * @return PaginatedResult<Restaurant>
     */
    public function list(int $page, int $limit, ?RestaurantType $type = null): PaginatedResult
    {
        $qb = $this->entityManager
            ->getRepository(Restaurant::class)
            ->createQueryBuilder('r')
            ->orderBy('r.createdAt', 'DESC')
            // createdAt has only second precision — see DeliveryRepository
            // for why a tiebreaker is required for stable pagination.
            ->addOrderBy('r.id', 'DESC');

        if (null !== $type) {
            $qb->andWhere('r.type = :type')->setParameter('type', $type);
        }

        return Paginator::paginate($qb, $page, $limit);
    }

    /**
     * The public catalogue: open restaurants (or grocery stores, depending
     * on $type) only, alphabetical for browsing.
     *
     * @return PaginatedResult<Restaurant>
     */
    public function listAvailable(int $page, int $limit, RestaurantType $type = RestaurantType::RESTAURANT): PaginatedResult
    {
        $qb = $this->entityManager
            ->getRepository(Restaurant::class)
            ->createQueryBuilder('r')
            ->andWhere('r.isAvailable = :available')
            ->andWhere('r.type = :type')
            ->setParameter('available', true)
            ->setParameter('type', $type)
            ->orderBy('r.name', 'ASC')
            // Two restaurants can share a name — see DeliveryRepository for
            // why a tiebreaker is required for stable pagination.
            ->addOrderBy('r.id', 'ASC');

        return Paginator::paginate($qb, $page, $limit);
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
            ->setIsAvailable($dto->isAvailable)
            ->setType(RestaurantType::from($dto->type));

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
     * Deletes a restaurant along with its categories, products and the
     * promotions scoped to it (platform-wide ones are untouched). Refuses
     * when the restaurant has any orders, since those reference it (and its
     * products) directly — deactivate it instead.
     */
    public function delete(Restaurant $restaurant): void
    {
        if ($this->orderRepository->count(['restaurant' => $restaurant]) > 0) {
            throw new ConflictException('This restaurant has existing orders and cannot be deleted. Deactivate it instead.');
        }

        // Photo files are only removed once the rows are actually gone, so a
        // failed flush can't leave a restaurant with its images deleted.
        $photos = [[$restaurant->getPhotoFilename(), self::PHOTO_SUBDIRECTORY]];

        foreach ($restaurant->getProducts() as $product) {
            $photos[] = [$product->getPhotoFilename(), 'products'];
            $this->entityManager->remove($product);
        }

        foreach ($restaurant->getCategories() as $category) {
            $this->entityManager->remove($category);
        }

        foreach ($this->promotionRepository->findBy(['restaurant' => $restaurant]) as $promotion) {
            $photos[] = [$promotion->getImageFilename(), 'promotions'];
            $this->entityManager->remove($promotion);
        }

        $this->entityManager->remove($restaurant);
        $this->entityManager->flush();

        foreach ($photos as [$filename, $subdirectory]) {
            $this->photoUploader->delete($filename, $subdirectory);
        }
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
