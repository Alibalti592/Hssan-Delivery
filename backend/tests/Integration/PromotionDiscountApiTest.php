<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\Delivery;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\Product;
use App\Entity\Promotion;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\DiscountType;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * Percentage and fixed-amount promotions really take money off orders:
 * by themselves when they have no code, with the code when they have one,
 * and never more than one per order.
 */
final class PromotionDiscountApiTest extends WebTestCase
{
    use SwitchesOffItsPromotions;

    private KernelBrowser $client;
    private EntityManagerInterface $entityManager;
    private string $token;
    private Restaurant $restaurant;
    private Product $pizza;
    private DeliveryZone $zone;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        self::getContainer()->get('cache.rate_limiter')->clear();

        $this->restaurant = $this->createRestaurant('Pizzeria');
        $this->pizza = $this->createProduct($this->restaurant, 'Pizza', '12.000');
        $this->zone = (new DeliveryZone())->setName('Promo Zone '.random_int(1000000, 999999999))->setFee('3.000');
        $this->entityManager->persist($this->zone);
        $this->entityManager->flush();

        $this->token = $this->login($this->createUser('ROLE_CLIENT'));
    }

    public function testARestaurantsPercentageAppliesByItself(): void
    {
        $this->createPromotion('-10 % chez Pizzeria', DiscountType::PERCENTAGE, '10', restaurant: $this->restaurant);

        $order = $this->placeOrder(quantity: 2);

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        // 2 × 12 = 24, minus 10 % = 21.600, plus 3 delivery.
        self::assertSame('2.400', $order['discountAmount']);
        self::assertSame('-10 % chez Pizzeria', $order['promotionTitle']);
        self::assertNull($order['promoCode']);
        self::assertSame('24.600', $order['totalAmount']);
    }

    public function testAnotherRestaurantsPromotionDoesNotApply(): void
    {
        $this->createPromotion('Ailleurs', DiscountType::PERCENTAGE, '50', restaurant: $this->createRestaurant('Ailleurs'));

        $order = $this->placeOrder(quantity: 1);

        self::assertSame('0.000', $order['discountAmount']);
        self::assertNull($order['promotionTitle']);
        self::assertSame('15.000', $order['totalAmount']);
    }

    public function testACodeAppliesOnlyWhenTyped(): void
    {
        $code = $this->uniqueCode();
        $this->createPromotion('Bienvenue', DiscountType::FIXED_AMOUNT, '5', code: $code);

        self::assertSame('0.000', $this->placeOrder(quantity: 1)['discountAmount']);

        // Any case, spaces around.
        $order = $this->placeOrder(quantity: 1, code: '  '.strtolower($code).' ');

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        self::assertSame('5.000', $order['discountAmount']);
        self::assertSame($code, $order['promoCode']);
        self::assertSame('10.000', $order['totalAmount']);
    }

    public function testAWrongOrMisplacedCodeIsRefusedWithAReason(): void
    {
        $this->placeOrder(quantity: 1, code: 'NOPE'.random_int(1000, 9999));
        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
        self::assertSame('Ce code promo n\'est pas valable.', $this->message());

        $code = $this->uniqueCode();
        $this->createPromotion('Chez Ailleurs', DiscountType::FIXED_AMOUNT, '5', code: $code, restaurant: $this->createRestaurant('Snack Ailleurs'));

        $this->placeOrder(quantity: 1, code: $code);
        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
        self::assertStringContainsString('valable seulement chez Snack Ailleurs', $this->message());
    }

    public function testOnlyTheBestPromotionApplies(): void
    {
        $this->createPromotion('-10 %', DiscountType::PERCENTAGE, '10', restaurant: $this->restaurant);
        $code = $this->uniqueCode();
        $this->createPromotion('-5 DT', DiscountType::FIXED_AMOUNT, '5', code: $code);

        // 10 % of 24 = 2.400 by itself; the code's 5 DT is better.
        $order = $this->placeOrder(quantity: 2, code: $code);
        self::assertSame('5.000', $order['discountAmount']);
        self::assertSame('-5 DT', $order['promotionTitle']);

        // 10 % of 120 = 12, better than the code's 5.
        $order = $this->placeOrder(quantity: 10, code: $code);
        self::assertSame('12.000', $order['discountAmount']);
        self::assertSame('-10 %', $order['promotionTitle']);
    }

    public function testAnAmountNeverExceedsTheItemsAndSkipsOffersAndFees(): void
    {
        $this->createPromotion('-50 DT', DiscountType::FIXED_AMOUNT, '50', restaurant: $this->restaurant);

        $order = $this->placeOrder(quantity: 1);
        // The 12 DT pizza is free; the 3 DT delivery is still due.
        self::assertSame('12.000', $order['discountAmount']);
        self::assertSame('3.000', $order['totalAmount']);

        // A fixed-price offer is already discounted.
        $offerProduct = $this->createProduct($this->restaurant, 'Menu duo', '20.000');
        $offer = $this->createPromotion('Menu duo', DiscountType::FIXED_PRICE, '20', restaurant: $this->restaurant);
        $offer->setProduct($offerProduct);
        $this->entityManager->flush();

        $order = $this->placeOrder(quantity: 1, productId: $offerProduct->getId());
        self::assertSame('0.000', $order['discountAmount']);
        self::assertSame('23.000', $order['totalAmount']);
    }

    public function testHiddenAndExpiredPromotionsDoNotApply(): void
    {
        $this->createPromotion('Cachée', DiscountType::PERCENTAGE, '30', restaurant: $this->restaurant)->setIsActive(false);
        $this->createPromotion('Finie', DiscountType::PERCENTAGE, '30', restaurant: $this->restaurant)
            ->setEndAt(new \DateTimeImmutable('-1 hour'));
        $this->entityManager->flush();

        self::assertSame('0.000', $this->placeOrder(quantity: 1)['discountAmount']);
    }

    public function testTheQuoteShowsTheTotalWithoutPlacingTheOrder(): void
    {
        $this->createPromotion('-10 %', DiscountType::PERCENTAGE, '10', restaurant: $this->restaurant);
        $orders = $this->entityManager->getRepository(Order::class)->count([]);

        $this->client->request('POST', '/api/orders/quote', server: $this->headers(), content: $this->orderBody(2, null, null));

        self::assertResponseIsSuccessful();
        self::assertSame([
            'subtotal' => '24.000',
            'discountAmount' => '2.400',
            'deliveryFee' => '3.000',
            'totalAmount' => '24.600',
            'promotionTitle' => '-10 %',
            'promoCode' => null,
        ], json_decode((string) $this->client->getResponse()->getContent(), true));
        self::assertSame($orders, $this->entityManager->getRepository(Order::class)->count([]));

        // A wrong code gets the same answer as when ordering.
        $this->client->request('POST', '/api/orders/quote', server: $this->headers(), content: $this->orderBody(2, null, 'NOPE'.random_int(1000, 9999)));
        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
    }

    public function testTheCourierSeesTheDiscountedAmountToCollect(): void
    {
        $this->createPromotion('-10 %', DiscountType::PERCENTAGE, '10', restaurant: $this->restaurant);
        $order = $this->placeOrder(quantity: 2);

        $courier = $this->createUser('ROLE_LIVREUR');
        $delivery = $this->entityManager->getRepository(Delivery::class)->findOneBy(['order' => $order['id']]);
        $delivery->setCourier($this->entityManager->getRepository(User::class)->find($courier->getId()));
        $delivery->setStatus(DeliveryStatus::ASSIGNED);
        $this->entityManager->flush();

        $this->client->request('GET', '/api/deliveries/mine', server: [
            'HTTP_AUTHORIZATION' => 'Bearer '.$this->login($courier),
        ]);
        $job = json_decode((string) $this->client->getResponse()->getContent(), true)['items'][0]['order'];

        self::assertSame('2.400', $job['discountAmount']);
        self::assertSame('-10 %', $job['promotionTitle']);
        self::assertSame('24.600', $job['totalAmount']);
    }

    /**
     * @return array<string, mixed>
     */
    private function placeOrder(int $quantity, ?string $code = null, ?int $productId = null): array
    {
        $this->client->request('POST', '/api/orders', server: $this->headers(), content: $this->orderBody($quantity, $productId, $code));

        return json_decode((string) $this->client->getResponse()->getContent(), true);
    }

    private function orderBody(int $quantity, ?int $productId, ?string $code): string
    {
        return json_encode([
            'restaurantId' => $this->restaurant->getId(),
            'items' => [['productId' => $productId ?? $this->pizza->getId(), 'quantity' => $quantity]],
            'deliveryAddress' => 'Rue de Marseille',
            'deliveryZoneId' => $this->zone->getId(),
            'promoCode' => $code,
        ]);
    }

    private function createPromotion(string $title, DiscountType $type, string $value, ?string $code = null, ?Restaurant $restaurant = null): Promotion
    {
        $promotion = (new Promotion())
            ->setTitle($title)
            ->setDiscountType($type)
            ->setDiscountValue($value)
            ->setPromoCode($code)
            ->setRestaurant(null === $restaurant ? null : $this->entityManager->find(Restaurant::class, $restaurant->getId()))
            ->setStartAt(new \DateTimeImmutable('-1 day'))
            ->setIsActive(true);
        $this->entityManager->persist($promotion);
        $this->entityManager->flush();

        return $promotion;
    }

    private function createRestaurant(string $name): Restaurant
    {
        $restaurant = (new Restaurant())->setName($name.' '.random_int(1000, 999999))->setIsAvailable(true);
        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        return $restaurant;
    }

    private function createProduct(Restaurant $restaurant, string $name, string $price): Product
    {
        // Fetched again: a request in between leaves the earlier one detached.
        $restaurant = $this->entityManager->find(Restaurant::class, $restaurant->getId());
        $category = (new Category())->setName('Plats')->setRestaurant($restaurant);
        $product = (new Product())
            ->setName($name)
            ->setPrice($price)
            ->setIsAvailable(true)
            ->setRestaurant($restaurant)
            ->setCategory($category);
        $this->entityManager->persist($category);
        $this->entityManager->persist($product);
        $this->entityManager->flush();

        return $product;
    }

    private function uniqueCode(): string
    {
        return 'PROMO'.random_int(100000, 999999);
    }

    private function createUser(string $role): User
    {
        $user = new User();
        $user->setName('Promo '.$role);
        $user->setPhone((string) random_int(20000000, 99999999));
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123'));
        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    private function login(User $user): string
    {
        $this->client->request('POST', '/api/auth/login', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'phone' => $user->getPhone(),
            'password' => 'password123',
        ]));
        self::assertResponseIsSuccessful();

        return json_decode((string) $this->client->getResponse()->getContent(), true)['token'];
    }

    /**
     * @return array<string, string>
     */
    private function headers(): array
    {
        return ['CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => 'Bearer '.$this->token];
    }

    private function message(): string
    {
        return json_decode((string) $this->client->getResponse()->getContent(), true)['message'];
    }
}
