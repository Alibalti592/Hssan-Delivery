<?php

namespace App\Service;

use App\Dto\Admin\CreatePromotionRequest;
use App\Dto\Admin\UpdatePromotionRequest;
use App\Entity\Category;
use App\Entity\Product;
use App\Entity\Promotion;
use App\Entity\Restaurant;
use App\Enum\DiscountType;
use App\Exception\InvalidOperationException;
use App\Pagination\PaginatedResult;
use App\Pagination\Paginator;
use App\Repository\CategoryRepository;
use App\Repository\OrderItemRepository;
use App\Repository\PromotionRepository;
use App\Repository\RestaurantRepository;
use App\Util\Money;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\File\UploadedFile;

final class PromotionService
{
    private const PHOTO_SUBDIRECTORY = 'promotions';
    private const PRODUCT_PHOTO_SUBDIRECTORY = 'products';

    /** Where a restaurant's offer products live in its menu. */
    public const OFFER_CATEGORY_NAME = 'Offres';

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly PromotionRepository $promotionRepository,
        private readonly RestaurantRepository $restaurantRepository,
        private readonly PhotoUploader $photoUploader,
        private readonly CategoryRepository $categoryRepository,
        private readonly OrderItemRepository $orderItemRepository,
    ) {
    }

    public function create(CreatePromotionRequest $dto): Promotion
    {
        $promotion = new Promotion();

        $this->applyRequest($promotion, $dto);

        $this->entityManager->persist($promotion);
        $stalePhoto = $this->syncOfferProduct($promotion);
        $this->entityManager->flush();

        $this->photoUploader->delete($stalePhoto, self::PRODUCT_PHOTO_SUBDIRECTORY);

        return $promotion;
    }

    public function update(Promotion $promotion, UpdatePromotionRequest $dto): Promotion
    {
        $this->applyRequest($promotion, $dto);
        $stalePhoto = $this->syncOfferProduct($promotion);

        $this->entityManager->flush();

        $this->photoUploader->delete($stalePhoto, self::PRODUCT_PHOTO_SUBDIRECTORY);

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
        $filenames = [[$promotion->getImageFilename(), self::PHOTO_SUBDIRECTORY]];
        $product = $promotion->getProduct();

        $promotion->setProduct(null);
        if (null !== $product) {
            $filenames[] = $this->retireOfferProduct($product);
        }

        $this->entityManager->remove($promotion);
        $this->entityManager->flush();

        foreach ($filenames as [$filename, $subdirectory]) {
            $this->photoUploader->delete($filename, $subdirectory);
        }
    }

    public function setPhoto(Promotion $promotion, UploadedFile $file): Promotion
    {
        $filename = $this->photoUploader->store($file, self::PHOTO_SUBDIRECTORY);

        $this->photoUploader->delete($promotion->getImageFilename(), self::PHOTO_SUBDIRECTORY);

        $promotion->setImageFilename($filename);
        $staleProductPhoto = $this->syncOfferProductPhoto($promotion);

        $this->entityManager->flush();

        $this->photoUploader->delete($staleProductPhoto, self::PRODUCT_PHOTO_SUBDIRECTORY);

        return $promotion;
    }

    public function removePhoto(Promotion $promotion): Promotion
    {
        $this->photoUploader->delete($promotion->getImageFilename(), self::PHOTO_SUBDIRECTORY);

        $promotion->setImageFilename(null);
        $staleProductPhoto = $this->syncOfferProductPhoto($promotion);

        $this->entityManager->flush();

        $this->photoUploader->delete($staleProductPhoto, self::PRODUCT_PHOTO_SUBDIRECTORY);

        return $promotion;
    }

    private function applyRequest(Promotion $promotion, CreatePromotionRequest|UpdatePromotionRequest $dto): void
    {
        if (null !== $dto->endAt && $dto->endAt <= $dto->startAt) {
            throw new InvalidOperationException('End date must be after the start date.');
        }

        $type = DiscountType::from((string) $dto->discountType);

        if (DiscountType::PERCENTAGE === $type && (float) $dto->discountValue > 100) {
            throw new InvalidOperationException('A percentage discount cannot exceed 100.');
        }

        $restaurant = null;

        if (null !== $dto->restaurantId) {
            $restaurant = $this->restaurantRepository->find($dto->restaurantId);

            if (null === $restaurant) {
                throw new InvalidOperationException('Restaurant not found.');
            }
        }

        $isOffer = DiscountType::FIXED_PRICE === $type;

        $promotion->setTitle((string) $dto->title);
        $promotion->setDescription($dto->description);
        $promotion->setDiscountType($type);
        $promotion->setDiscountValue($isOffer
            ? Money::fromMillimes(Money::toMillimes((string) $dto->discountValue))
            : (string) $dto->discountValue);
        // An offer is ordered at its price, not unlocked with a code.
        $promotion->setPromoCode($isOffer ? null : $dto->promoCode);
        $promotion->setStartAt($dto->startAt);
        $promotion->setEndAt($dto->endAt);
        $promotion->setIsActive($dto->isActive);
        $promotion->setRestaurant($restaurant);
        $promotion->setItems($isOffer ? array_values(array_map('trim', $dto->items)) : []);
    }

    /**
     * Keeps a FIXED_PRICE offer's product in step with it: created on first
     * save in the restaurant's "Offres" category, then renamed/repriced with
     * the offer. Whether it can be seen or ordered follows the offer being
     * live (see ProductService::listAvailableForRestaurant and
     * OrderService), so it needs no availability of its own.
     *
     * A promotion that stops being an offer, or moves to another
     * restaurant, retires its old product.
     *
     * @return string|null a retired product's photo, for the caller to
     *                     delete once the change is flushed
     */
    private function syncOfferProduct(Promotion $promotion): ?string
    {
        $stalePhoto = null;
        $product = $promotion->getProduct();
        $restaurant = $promotion->getRestaurant();
        $isOffer = DiscountType::FIXED_PRICE === $promotion->getDiscountType() && null !== $restaurant;

        if (null !== $product && (!$isOffer || $product->getRestaurant() !== $restaurant)) {
            $promotion->setProduct(null);
            [$stalePhoto] = $this->retireOfferProduct($product);
            $product = null;
        }

        if (!$isOffer) {
            return $stalePhoto;
        }

        if (null === $product) {
            $product = new Product();
            $product->setRestaurant($restaurant);
            $product->setCategory($this->offerCategory($restaurant));
            $this->entityManager->persist($product);
            $promotion->setProduct($product);
            $this->syncOfferProductPhoto($promotion);
        }

        $items = $promotion->getItems();

        $product->setName((string) $promotion->getTitle());
        $product->setDescription([] !== $items ? implode(' • ', $items) : $promotion->getDescription());
        $product->setPrice((string) $promotion->getDiscountValue());
        $product->setOptions([]);
        $product->setIsAvailable(true);

        return $stalePhoto;
    }

    /**
     * Gives an offer's product a copy of the offer's flyer, so it shows in
     * the restaurant's menu too.
     *
     * @return string|null the product's previous photo, for the caller to
     *                     delete once the change is flushed
     */
    private function syncOfferProductPhoto(Promotion $promotion): ?string
    {
        $product = $promotion->getProduct();

        if (null === $product) {
            return null;
        }

        $previous = $product->getPhotoFilename();
        $product->setPhotoFilename($this->photoUploader->copy(
            $promotion->getImageFilename(),
            self::PHOTO_SUBDIRECTORY,
            self::PRODUCT_PHOTO_SUBDIRECTORY
        ));

        return $previous;
    }

    /**
     * An offer's product is removed with it -- unless it has been ordered,
     * in which case order history still points at it, so it is kept but
     * hidden from the menu for good.
     *
     * @return array{0: ?string, 1: string} its photo to delete after the flush
     */
    private function retireOfferProduct(Product $product): array
    {
        if ($this->orderItemRepository->count(['product' => $product]) > 0) {
            $product->setIsAvailable(false);

            return [null, self::PRODUCT_PHOTO_SUBDIRECTORY];
        }

        $photo = $product->getPhotoFilename();
        $this->entityManager->remove($product);

        return [$photo, self::PRODUCT_PHOTO_SUBDIRECTORY];
    }

    private function offerCategory(Restaurant $restaurant): Category
    {
        $category = $this->categoryRepository->findOneBy([
            'restaurant' => $restaurant,
            'name' => self::OFFER_CATEGORY_NAME,
        ]);

        if (null === $category) {
            $category = new Category();
            $category->setName(self::OFFER_CATEGORY_NAME);
            $category->setRestaurant($restaurant);
            $this->entityManager->persist($category);
        }

        return $category;
    }
}
