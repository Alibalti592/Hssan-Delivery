<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\Delivery;
use App\Entity\DeliveryZone;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\OrderStatus;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;

final class OrderApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function testCreateOrderAutomaticallyCreatesPendingDelivery(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct(
            $restaurant,
            $category
        );
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => [
                    [
                        'productId' => $product->getId(),
                        'quantity' => 2,
                    ],
                ],
                'note' => 'Integration test',
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => $zone->getId(),
            ])
        );

        self::assertResponseStatusCodeSame(201);

        $responseData = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($responseData);

        self::assertSame(
            OrderStatus::PENDING->value,
            $responseData['status']
        );

        self::assertSame(
            '4.000',
            $responseData['deliveryFee']
        );

        self::assertSame(
            $zone->getId(),
            $responseData['deliveryZoneId']
        );

        self::assertSame(
            '29.000',
            $responseData['totalAmount']
        );

        self::assertArrayHasKey('id', $responseData);

        $orderId = $responseData['id'];

        $this->entityManager->clear();

        $delivery = $this->entityManager
            ->getRepository(Delivery::class)
            ->findOneBy([
                'order' => $orderId,
            ]);

        self::assertNotNull($delivery);

        self::assertSame(
            DeliveryStatus::PENDING,
            $delivery->getStatus()
        );

        self::assertNull(
            $delivery->getCourier()
        );

        self::assertNotNull(
            $delivery->getOrder()
        );

        self::assertSame(
            $orderId,
            $delivery->getOrder()->getId()
        );
    }

    public function testCreateOrderFailsWhenRestaurantDoesNotExist(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct(
            $restaurant,
            $category
        );

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'restaurantId' => 999999,
                'items' => [
                    [
                        'productId' => $product->getId(),
                        'quantity' => 1,
                    ],
                ],
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => 1,
            ])
        );

        self::assertResponseStatusCodeSame(400);

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'Restaurant not found.',
            $response['message']
        );
    }

    public function testCreateOrderFailsWhenRestaurantIsUnavailable(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $restaurant = $this->createTestRestaurant(false);
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct(
            $restaurant,
            $category
        );

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => [
                    [
                        'productId' => $product->getId(),
                        'quantity' => 1,
                    ],
                ],
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => 1,
            ])
        );

        self::assertResponseStatusCodeSame(400);

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'Restaurant is currently unavailable.',
            $response['message']
        );
    }

    public function testCreateOrderFailsWhenProductDoesNotExist(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $restaurant = $this->createTestRestaurant();
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => [
                    [
                        'productId' => 999999,
                        'quantity' => 1,
                    ],
                ],
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => $zone->getId(),
            ])
        );

        self::assertResponseStatusCodeSame(400);

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'Product 999999 not found.',
            $response['message']
        );
    }

    public function testCreateOrderFailsWhenProductBelongsToAnotherRestaurant(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $restaurant = $this->createTestRestaurant();
        $otherRestaurant = $this->createTestRestaurant();

        $category = $this->createTestCategory($otherRestaurant);

        $product = $this->createTestProduct(
            $otherRestaurant,
            $category
        );
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => [
                    [
                        'productId' => $product->getId(),
                        'quantity' => 1,
                    ],
                ],
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => $zone->getId(),
            ])
        );

        self::assertResponseStatusCodeSame(400);

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            "Product {$product->getId()} does not belong to this restaurant.",
            $response['message']
        );
    }

    public function testCreateOrderFailsWhenProductIsUnavailable(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);

        $product = $this->createTestProduct(
            $restaurant,
            $category,
            false
        );
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => [
                    [
                        'productId' => $product->getId(),
                        'quantity' => 1,
                    ],
                ],
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => $zone->getId(),
            ])
        );

        self::assertResponseStatusCodeSame(400);

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            "Product {$product->getId()} is currently unavailable.",
            $response['message']
        );
    }

    public function testCreateOrderFailsWhenQuantityIsInvalid(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct(
            $restaurant,
            $category
        );

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => [
                    [
                        'productId' => $product->getId(),
                        'quantity' => 0,
                    ],
                ],
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => 1,
            ])
        );

        self::assertResponseStatusCodeSame(422);

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'Validation failed.',
            $response['message']
        );

        self::assertNotEmpty(
            $response['errors']
        );
    }

    public function testCreateOrderFailsWhenDeliveryZoneDoesNotExist(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct(
            $restaurant,
            $category
        );

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => [
                    [
                        'productId' => $product->getId(),
                        'quantity' => 1,
                    ],
                ],
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => 999999,
            ])
        );

        self::assertResponseStatusCodeSame(400);

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'Delivery zone not found.',
            $response['message']
        );
    }

    public function testDeliveryZonesCanBeListed(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/delivery-zones',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);

        $names = array_column($response, 'name');

        self::assertContains($zone->getName(), $names);

        $fees = array_column($response, 'fee', 'name');

        self::assertSame('4.000', $fees[$zone->getName()]);
    }

    private function createTestUser(): User
    {
        $phone = '221' . random_int(100000, 999999);

        $user = new User();

        $user->setName('Test Client');
        $user->setPhone($phone);
        $user->setRoles(['ROLE_USER']);
        $user->setVerifiedAt(new \DateTimeImmutable());

        $passwordHasher = self::getContainer()
            ->get(UserPasswordHasherInterface::class);

        $user->setPassword(
            $passwordHasher->hashPassword(
                $user,
                'password123'
            )
        );

        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    private function createTestRestaurant(
        bool $available = true
    ): Restaurant {
        $restaurant = new Restaurant();

        $restaurant->setName(
            'Test Restaurant ' . random_int(1000, 9999)
        );

        $restaurant->setIsAvailable($available);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        return $restaurant;
    }

    private function createTestCategory(
        Restaurant $restaurant
    ): Category {
        $category = new Category();

        $category->setName(
            'Test Category ' . random_int(1000, 9999)
        );

        $category->setRestaurant($restaurant);

        $this->entityManager->persist($category);
        $this->entityManager->flush();

        return $category;
    }

    private function createTestProduct(
        Restaurant $restaurant,
        Category $category,
        bool $available = true
    ): Product {
        $product = new Product();

        $product->setName(
            'Test Pizza ' . random_int(1000, 9999)
        );

        $product->setPrice('12.500');
        $product->setIsAvailable($available);
        $product->setRestaurant($restaurant);
        $product->setCategory($category);

        $this->entityManager->persist($product);
        $this->entityManager->flush();

        return $product;
    }

    private function createTestDeliveryZone(
        string $fee
    ): DeliveryZone {
        $zone = new DeliveryZone();

        $zone->setName('Test Zone '.random_int(1000, 9999));
        $zone->setFee($fee);

        $this->entityManager->persist($zone);
        $this->entityManager->flush();

        return $zone;
    }

    private function authenticateClient(
        KernelBrowser $client,
        User $user
    ): string {
        $client->request(
            'POST',
            '/api/auth/login',
            server: [
                'CONTENT_TYPE' => 'application/json',
            ],
            content: json_encode([
                'phone' => $user->getPhone(),
                'password' => 'password123',
            ])
        );

        self::assertResponseIsSuccessful();

        $loginData = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($loginData);

        self::assertArrayHasKey(
            'token',
            $loginData
        );

        return $loginData['token'];
    }
}
