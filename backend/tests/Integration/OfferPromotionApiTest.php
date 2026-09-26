<?php

namespace App\Tests\Integration;

use App\Entity\DeliveryZone;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Service\PromotionService;
use Doctrine\ORM\EntityManagerInterface;
use PHPUnit\Framework\Attributes\DataProvider;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * FIXED_PRICE promotions: a bundle sold at a set price ("2 sandwiches +
 * frites — 11 DT"), ordered through a product the backend manages for it.
 */
final class OfferPromotionApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;
    private KernelBrowser $client;
    private string $adminToken;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        $this->adminToken = $this->authenticate($this->createUser('ROLE_ADMIN'));
    }

    public function testCreatingAnOfferCreatesItsProductInTheOffersCategory(): void
    {
        $restaurant = $this->createRestaurant();

        $offer = $this->saveOffer('POST', '/api/admin/promotions', $restaurant, [
            'discountValue' => '11',
            'items' => ['  2 Sandwichs Chawarma  ', 'Frites dorées', '2 Sauces'],
            'endAt' => null,
        ]);

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        self::assertSame('FIXED_PRICE', $offer['discountType']);
        self::assertSame('11.000', $offer['discountValue']);
        self::assertSame(['2 Sandwichs Chawarma', 'Frites dorées', '2 Sauces'], $offer['items']);
        self::assertNull($offer['endAt']);
        self::assertNull($offer['promoCode']);
        self::assertIsInt($offer['productId']);

        $product = $this->findProduct($offer['productId']);

        self::assertSame('2 Sandwiches Chawarma', $product->getName());
        self::assertSame('11.000', $product->getPrice());
        self::assertSame('2 Sandwichs Chawarma • Frites dorées • 2 Sauces', $product->getDescription());
        self::assertSame($restaurant->getId(), $product->getRestaurant()->getId());
        self::assertSame(PromotionService::OFFER_CATEGORY_NAME, $product->getCategory()->getName());
        self::assertTrue($product->isAvailable());
    }

    public function testUpdatingAnOfferKeepsItsProductInSync(): void
    {
        $restaurant = $this->createRestaurant();
        $offer = $this->saveOffer('POST', '/api/admin/promotions', $restaurant);

        $updated = $this->saveOffer('PUT', '/api/admin/promotions/'.$offer['id'], $restaurant, [
            'title' => '3 Sandwiches Chawarma',
            'discountValue' => '15.500',
        ]);

        self::assertResponseIsSuccessful();
        self::assertSame($offer['productId'], $updated['productId']);

        $product = $this->findProduct($updated['productId']);

        self::assertSame('3 Sandwiches Chawarma', $product->getName());
        self::assertSame('15.500', $product->getPrice());
    }

    public function testAnOfferIsOnTheMenuAndOrderableOnlyWhileVisible(): void
    {
        $restaurant = $this->createRestaurant();
        $zone = $this->createZone();
        $offer = $this->saveOffer('POST', '/api/admin/promotions', $restaurant, ['discountValue' => '11']);
        $clientToken = $this->authenticate($this->createUser('ROLE_USER'));

        self::assertContains($offer['productId'], $this->menuProductIds($restaurant, $clientToken));
        self::assertContains($offer['id'], $this->publicPromotionIds($clientToken));

        $order = $this->postOrder($clientToken, $restaurant, $zone, $offer['productId'], 2);

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        self::assertSame('11.000', $order['items'][0]['unitPrice']);
        self::assertSame(2, $order['items'][0]['quantity']);
        self::assertSame('2 Sandwiches Chawarma', $order['items'][0]['productName']);
        self::assertSame('25.000', $order['totalAmount']);

        // The admin hides it: gone from the promotions, the menu, and
        // ordering.
        $this->client->request(
            'PATCH',
            '/api/admin/promotions/'.$offer['id'].'/active',
            server: $this->adminHeaders(),
            content: json_encode(['isActive' => false])
        );
        self::assertResponseIsSuccessful();

        self::assertNotContains($offer['productId'], $this->menuProductIds($restaurant, $clientToken));
        self::assertNotContains($offer['id'], $this->publicPromotionIds($clientToken));

        $rejected = $this->postOrder($clientToken, $restaurant, $zone, $offer['productId'], 1);

        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
        self::assertStringContainsString('no longer available', json_encode($rejected));
    }

    public function testAnExpiredOfferCannotBeOrdered(): void
    {
        $restaurant = $this->createRestaurant();
        $zone = $this->createZone();
        $offer = $this->saveOffer('POST', '/api/admin/promotions', $restaurant, [
            'startAt' => (new \DateTimeImmutable('-2 weeks'))->format(\DateTimeInterface::ATOM),
            'endAt' => (new \DateTimeImmutable('-1 week'))->format(\DateTimeInterface::ATOM),
        ]);
        $clientToken = $this->authenticate($this->createUser('ROLE_USER'));

        self::assertNotContains($offer['productId'], $this->menuProductIds($restaurant, $clientToken));

        $this->postOrder($clientToken, $restaurant, $zone, $offer['productId'], 1);

        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
    }

    public function testDeletingAnOfferRemovesItsUnorderedProduct(): void
    {
        $restaurant = $this->createRestaurant();
        $offer = $this->saveOffer('POST', '/api/admin/promotions', $restaurant);

        $this->client->request('DELETE', '/api/admin/promotions/'.$offer['id'], server: $this->adminHeaders());

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $this->entityManager->clear();
        self::assertNull($this->entityManager->getRepository(Product::class)->find($offer['productId']));
    }

    public function testDeletingAnOrderedOfferKeepsItsProductForOrderHistory(): void
    {
        $restaurant = $this->createRestaurant();
        $zone = $this->createZone();
        $offer = $this->saveOffer('POST', '/api/admin/promotions', $restaurant);
        $clientToken = $this->authenticate($this->createUser('ROLE_USER'));

        $order = $this->postOrder($clientToken, $restaurant, $zone, $offer['productId'], 1);
        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);

        $this->client->request('DELETE', '/api/admin/promotions/'.$offer['id'], server: $this->adminHeaders());
        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        // Still on the order, but off the menu for good.
        $product = $this->findProduct($offer['productId']);
        self::assertFalse($product->isAvailable());
        self::assertNotContains($offer['productId'], $this->menuProductIds($restaurant, $clientToken));

        $this->client->request('GET', '/api/orders/'.$order['id'], server: ['HTTP_AUTHORIZATION' => 'Bearer '.$clientToken]);
        self::assertResponseIsSuccessful();
    }

    public function testTurningAnOfferIntoAPlainDiscountRetiresItsProduct(): void
    {
        $restaurant = $this->createRestaurant();
        $offer = $this->saveOffer('POST', '/api/admin/promotions', $restaurant);

        $updated = $this->saveOffer('PUT', '/api/admin/promotions/'.$offer['id'], $restaurant, [
            'discountType' => 'PERCENTAGE',
            'discountValue' => '10',
            'items' => ['ignored'],
        ]);

        self::assertResponseIsSuccessful();
        self::assertNull($updated['productId']);
        self::assertSame([], $updated['items']);

        $this->entityManager->clear();
        self::assertNull($this->entityManager->getRepository(Product::class)->find($offer['productId']));
    }

    public function testMovingAnOfferToAnotherRestaurantMovesItsProduct(): void
    {
        $offer = $this->saveOffer('POST', '/api/admin/promotions', $this->createRestaurant());
        $other = $this->createRestaurant();

        $updated = $this->saveOffer('PUT', '/api/admin/promotions/'.$offer['id'], $other);

        self::assertResponseIsSuccessful();
        self::assertNotSame($offer['productId'], $updated['productId']);
        self::assertSame($other->getId(), $this->findProduct($updated['productId'])->getRestaurant()->getId());
    }

    public function testAPlainDiscountCanAlsoRunWithoutAnEndDate(): void
    {
        $this->client->request(
            'POST',
            '/api/admin/promotions',
            server: $this->adminHeaders(),
            content: json_encode([
                'title' => 'Open-ended',
                'discountType' => 'PERCENTAGE',
                'discountValue' => '10',
                'startAt' => (new \DateTimeImmutable('-1 day'))->format(\DateTimeInterface::ATOM),
                'endAt' => null,
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);

        $id = json_decode($this->client->getResponse()->getContent(), true)['id'];
        $clientToken = $this->authenticate($this->createUser('ROLE_USER'));

        self::assertContains($id, $this->publicPromotionIds($clientToken));
    }

    /**
     * @param array<string, mixed> $overrides
     */
    #[DataProvider('invalidOffers')]
    public function testInvalidOffersAreRejected(array $overrides, bool $withRestaurant): void
    {
        $this->saveOffer('POST', '/api/admin/promotions', $withRestaurant ? $this->createRestaurant() : null, $overrides);

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    /**
     * @return iterable<string, array{array<string, mixed>, bool}>
     */
    public static function invalidOffers(): iterable
    {
        yield 'no restaurant' => [[], false];
        yield 'zero price' => [['discountValue' => '0'], true];
        yield 'blank item' => [['items' => ['Frites', ' ']], true];
        yield 'too many items' => [['items' => array_fill(0, 11, 'Frites')], true];
        yield 'item too long' => [['items' => [str_repeat('a', 101)]], true];
    }

    /**
     * @param array<string, mixed> $overrides
     *
     * @return array<string, mixed>
     */
    private function saveOffer(string $method, string $url, ?Restaurant $restaurant, array $overrides = []): array
    {
        $this->client->request(
            $method,
            $url,
            server: $this->adminHeaders(),
            content: json_encode($overrides + [
                'title' => '2 Sandwiches Chawarma',
                'description' => 'Offre spéciale',
                'discountType' => 'FIXED_PRICE',
                'discountValue' => '11.000',
                'items' => ['2 Sandwichs Chawarma', 'Frites dorées'],
                'startAt' => (new \DateTimeImmutable('-1 day'))->format(\DateTimeInterface::ATOM),
                'endAt' => (new \DateTimeImmutable('+1 week'))->format(\DateTimeInterface::ATOM),
                'isActive' => true,
                'restaurantId' => $restaurant?->getId(),
            ])
        );

        return json_decode($this->client->getResponse()->getContent(), true);
    }

    /**
     * @return array<string, mixed>
     */
    private function postOrder(string $token, Restaurant $restaurant, DeliveryZone $zone, int $productId, int $quantity): array
    {
        $this->client->request(
            'POST',
            '/api/orders',
            server: ['CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => 'Bearer '.$token],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => [['productId' => $productId, 'quantity' => $quantity]],
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => $zone->getId(),
            ])
        );

        return json_decode($this->client->getResponse()->getContent(), true);
    }

    /**
     * @return list<int>
     */
    private function menuProductIds(Restaurant $restaurant, string $token): array
    {
        $this->client->request(
            'GET',
            '/api/restaurants/'.$restaurant->getId().'/products?limit=100',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]
        );
        self::assertResponseIsSuccessful();

        return array_column(json_decode($this->client->getResponse()->getContent(), true)['items'], 'id');
    }

    /**
     * @return list<int>
     */
    private function publicPromotionIds(string $token): array
    {
        $this->client->request('GET', '/api/promotions', server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]);
        self::assertResponseIsSuccessful();

        return array_column(json_decode($this->client->getResponse()->getContent(), true), 'id');
    }

    private function findProduct(int $id): Product
    {
        $this->entityManager->clear();
        $product = $this->entityManager->getRepository(Product::class)->find($id);
        self::assertNotNull($product);

        return $product;
    }

    /**
     * @return array<string, string>
     */
    private function adminHeaders(): array
    {
        return ['CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => 'Bearer '.$this->adminToken];
    }

    private function createRestaurant(): Restaurant
    {
        $restaurant = (new Restaurant())->setName('Offer Restaurant '.random_int(1000, 999999));
        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        return $restaurant;
    }

    private function createZone(): DeliveryZone
    {
        $zone = (new DeliveryZone())->setName('Offer Zone '.random_int(1000000, 999999999))->setFee('3.000');
        $this->entityManager->persist($zone);
        $this->entityManager->flush();

        return $zone;
    }

    private function createUser(string $role): User
    {
        $user = new User();
        $user->setName($role);
        $user->setPhone('2'.random_int(10000000, 99999999));
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123'));

        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    private function authenticate(User $user): string
    {
        $this->client->request(
            'POST',
            '/api/auth/login',
            server: ['CONTENT_TYPE' => 'application/json'],
            content: json_encode(['phone' => $user->getPhone(), 'password' => 'password123'])
        );
        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        return json_decode($this->client->getResponse()->getContent(), true)['token'];
    }
}
