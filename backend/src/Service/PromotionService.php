<?php

namespace App\Service;

use App\Dto\Admin\CreatePromotionRequest;
use App\Dto\Admin\UpdatePromotionRequest;
use App\Entity\Promotion;
use App\Enum\DiscountType;
use App\Exception\InvalidOperationException;
use App\Pagination\PaginatedResult;
use App\Pagination\Paginator;
use App\Repository\PromotionRepository;
use App\Repository\RestaurantRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\File\UploadedFile;

final class PromotionService
{
    private const PHOTO_SUBDIRECTORY = 'promotions';

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly PromotionRepository $promotionRepository,
        private readonly RestaurantRepository $restaurantRepository,
        private readonly PhotoUploader $photoUploader,
    ) {
    }

    public function create(CreatePromotionRequest $dto): Promotion
    {
        $promotion = new Promotion();

        $this->applyRequest($promotion, $dto->title, $dto->description, $dto->discountType, $dto->discountValue, $dto->promoCode, $dto->startAt, $dto->endAt, $dto->isActive, $dto->restaurantId);

        $this->entityManager->persist($promotion);
        $this->entityManager->flush();

        return $promotion;
    }

    public function update(Promotion $promotion, UpdatePromotionRequest $dto): Promotion
    {
        $this->applyRequest($promotion, $dto->title, $dto->description, $dto->discountType, $dto->discountValue, $dto->promoCode, $dto->startAt, $dto->endAt, $dto->isActive, $dto->restaurantId);

        $this->entityManager->flush();

        return $promotion;
    }

    /**
     * @return PaginatedResult<Promotion>
     */
    public function list(int $page, int $limit): PaginatedResult
    {
        $qb = $this->promotionRepository->createQueryBuilder('p')
            ->orderBy('p.createdAt', 'DESC')
            ->addOrderBy('p.id', 'DESC');

        return Paginator::paginate($qb, $page, $limit);
    }

    /**
     * Publicly visible promotions right now: active and within their
     * validity window. See Promotion::isCurrentlyValid — this query mirrors
     * that same rule server-side so an expired/inactive promotion can never
     * leak through the public endpoint.
     *
     * @return Promotion[]
     */
    public function listCurrentlyValid(): array
    {
        return $this->promotionRepository->findCurrentlyValid(new \DateTimeImmutable());
    }

    public function get(int $id): ?Promotion
    {
        return $this->promotionRepository->find($id);
    }

    /**
     * A promotion found this way is guaranteed valid right now — used by the
     * public show endpoint so a client can't fetch an expired/inactive one
     * by guessing its id.
     */
    public function getIfCurrentlyValid(int $id): ?Promotion
    {
        $promotion = $this->promotionRepository->find($id);

        if (null === $promotion || !$promotion->isCurrentlyValid(new \DateTimeImmutable())) {
            return null;
        }

        return $promotion;
    }

    public function setActive(Promotion $promotion, bool $isActive): Promotion
    {
        $promotion->setIsActive($isActive);

        $this->entityManager->flush();

        return $promotion;
    }

    public function delete(Promotion $promotion): void
    {
        $this->photoUploader->delete($promotion->getImageFilename(), self::PHOTO_SUBDIRECTORY);

        $this->entityManager->remove($promotion);
        $this->entityManager->flush();
    }

    public function setPhoto(Promotion $promotion, UploadedFile $file): Promotion
    {
        $filename = $this->photoUploader->store($file, self::PHOTO_SUBDIRECTORY);

        $this->photoUploader->delete($promotion->getImageFilename(), self::PHOTO_SUBDIRECTORY);

        $promotion->setImageFilename($filename);

        $this->entityManager->flush();

        return $promotion;
    }

    public function removePhoto(Promotion $promotion): Promotion
    {
        $this->photoUploader->delete($promotion->getImageFilename(), self::PHOTO_SUBDIRECTORY);

        $promotion->setImageFilename(null);

        $this->entityManager->flush();

        return $promotion;
    }

    private function applyRequest(
        Promotion $promotion,
        string $title,
        ?string $description,
        string $discountType,
        string $discountValue,
        ?string $promoCode,
        \DateTimeImmutable $startAt,
        \DateTimeImmutable $endAt,
        bool $isActive,
        ?int $restaurantId,
    ): void {
        if ($endAt <= $startAt) {
            throw new InvalidOperationException('End date must be after the start date.');
        }

        $type = DiscountType::from($discountType);

        if (DiscountType::PERCENTAGE === $type && (float) $discountValue > 100) {
            throw new InvalidOperationException('A percentage discount cannot exceed 100.');
        }

        $restaurant = null;

        if (null !== $restaurantId) {
            $restaurant = $this->restaurantRepository->find($restaurantId);

            if (null === $restaurant) {
                throw new InvalidOperationException('Restaurant not found.');
            }
        }

        $promotion->setTitle($title);
        $promotion->setDescription($description);
        $promotion->setDiscountType($type);
        $promotion->setDiscountValue($discountValue);
        $promotion->setPromoCode($promoCode);
        $promotion->setStartAt($startAt);
        $promotion->setEndAt($endAt);
        $promotion->setIsActive($isActive);
        $promotion->setRestaurant($restaurant);
    }
}
