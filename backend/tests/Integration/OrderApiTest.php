<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\Delivery;
use App\Entity\DeliveryZone;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\DeliveryType;
use App\Enum\OrderStatus;
use App\Enum\RestaurantType;
use Doctrine\ORM\EntityManagerInterface;
use PHPUnit\Framework\Attributes\DataProvider;
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
            DeliveryType::RESTAURANT->value,
            $responseData['deliveryType']
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

        self::assertSame(
            DeliveryType::RESTAURANT,
            $delivery->getOrder()->getDeliveryType()
        );
    }

    public function testOrderAgainstAGroceryStoreGetsGroceryDeliveryType(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $grocery = $this->createTestRestaurant(true, RestaurantType::GROCERY);
        $category = $this->createTestCategory($grocery);
        $product = $this->createTestProduct($grocery, $category);
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
                'restaurantId' => $grocery->getId(),
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

        self::assertResponseStatusCodeSame(201);

        $responseData = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            DeliveryType::GROCERY->value,
            $responseData['deliveryType']
        );
    }

    public function testCreateParcelOrderHasNoRestaurantAndPricesOffTheZoneFeeAlone(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $zone = $this->createTestDeliveryZone('5.000');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders/parcels',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'pickupAddress' => '1 Rue de Marseille, Tunis',
                'deliveryAddress' => '20 Avenue Habib Bourguiba, Tunis',
                'recipientName' => 'Amira Ben Salah',
                'recipientPhone' => '22334455',
                'note' => 'Documents fragiles',
                'deliveryZoneId' => $zone->getId(),
            ])
        );

        self::assertResponseStatusCodeSame(201);

        $responseData = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertNull($responseData['restaurantId']);
        self::assertNull($responseData['restaurantName']);
        self::assertSame([], $responseData['items']);
        self::assertSame('1 Rue de Marseille, Tunis', $responseData['pickupAddress']);
        self::assertSame('20 Avenue Habib Bourguiba, Tunis', $responseData['deliveryAddress']);
        self::assertSame('Amira Ben Salah', $responseData['recipientName']);
        self::assertSame('22334455', $responseData['recipientPhone']);
        self::assertSame('5.000', $responseData['deliveryFee']);
        self::assertSame('5.000', $responseData['totalAmount']);
        self::assertSame(DeliveryType::PARCEL->value, $responseData['deliveryType']);
        self::assertSame(OrderStatus::PENDING->value, $responseData['status']);

        $orderId = $responseData['id'];

        $this->entityManager->clear();

        $delivery = $this->entityManager
            ->getRepository(Delivery::class)
            ->findOneBy(['order' => $orderId]);

        self::assertNotNull($delivery);
        self::assertSame(DeliveryStatus::PENDING, $delivery->getStatus());
        self::assertSame(DeliveryType::PARCEL, $delivery->getOrder()->getDeliveryType());
        self::assertNull($delivery->getOrder()->getRestaurant());
    }

    public function testCreateParcelOrderFailsWhenRequiredFieldsAreMissing(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders/parcels',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'pickupAddress' => '',
                'deliveryAddress' => '20 Avenue Habib Bourguiba, Tunis',
                'recipientName' => '',
                'recipientPhone' => '',
                'deliveryZoneId' => null,
            ])
        );

        self::assertResponseStatusCodeSame(422);
    }

    public function testCreateParcelOrderFailsWhenDeliveryZoneDoesNotExist(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/orders/parcels',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'pickupAddress' => '1 Rue de Marseille, Tunis',
                'deliveryAddress' => '20 Avenue Habib Bourguiba, Tunis',
                'recipientName' => 'Amira Ben Salah',
                'recipientPhone' => '22334455',
                'deliveryZoneId' => 999999,
            ])
        );

        self::assertResponseStatusCodeSame(400);
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

    public function testOrderCreationIsRateLimitedAfterTooManyAttempts(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        self::getContainer()->get('cache.rate_limiter')->clear();

        $user = $this->createTestUser();

        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct(
            $restaurant,
            $category
        );
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);

        $payload = json_encode([
            'restaurantId' => $restaurant->getId(),
            'items' => [
                [
                    'productId' => $product->getId(),
                    'quantity' => 1,
                ],
            ],
            'deliveryAddress' => 'Tunis, Tunisia',
            'deliveryZoneId' => $zone->getId(),
        ]);

        // The configured limit is 20 attempts per 10 minutes per user id
        // (see config/packages/rate_limiter.yaml).
        for ($i = 0; $i < 20; ++$i) {
            $client->request(
                'POST',
                '/api/orders',
                server: [
                    'CONTENT_TYPE' => 'application/json',
                    'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
                ],
                content: $payload
            );

            self::assertResponseStatusCodeSame(201);
        }

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: $payload
        );

        self::assertResponseStatusCodeSame(429);

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);
        self::assertSame(
            'Trop de tentatives. Réessayez plus tard.',
            $response['message']
        );

        // Don't leak an exhausted limiter into whichever test runs next.
        self::getContainer()->get('cache.rate_limiter')->clear();
    }

    public function testOrderingAProductOptionChargesAndRecordsThatOption(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $pizza = $this->createTestProductWithOptions($restaurant, $category);
        $zone = $this->createTestDeliveryZone('4.000');
        $token = $this->authenticateClient($client, $user);

        $response = $this->postOrder($client, $token, $restaurant, $zone, [
            ['productId' => $pizza->getId(), 'option' => 'Familiale', 'quantity' => 2],
            ['productId' => $pizza->getId(), 'option' => 'M', 'quantity' => 1],
        ]);

        self::assertResponseStatusCodeSame(201);

        // 2 x 22.000 + 1 x 12.000 + 4.000 delivery
        self::assertSame('60.000', $response['totalAmount']);
        self::assertSame(
            [['Familiale', '22.000', 2], ['M', '12.000', 1]],
            array_map(
                static fn (array $item) => [$item['option'], $item['unitPrice'], $item['quantity']],
                $response['items']
            )
        );
    }

    #[DataProvider('invalidOptionChoices')]
    public function testOrderItemOptionMustMatchTheProduct(bool $productHasOptions, ?string $option, string $expectedMessage): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $productHasOptions
            ? $this->createTestProductWithOptions($restaurant, $category)
            : $this->createTestProduct($restaurant, $category);
        $zone = $this->createTestDeliveryZone('4.000');
        $token = $this->authenticateClient($client, $user);

        $response = $this->postOrder($client, $token, $restaurant, $zone, [
            ['productId' => $product->getId(), 'option' => $option, 'quantity' => 1],
        ]);

        self::assertResponseStatusCodeSame(400);
        self::assertSame(
            sprintf($expectedMessage, $product->getId()),
            $response['message']
        );
    }

    public static function invalidOptionChoices(): iterable
    {
        yield 'no option chosen' => [true, null, 'Choose an option for product %d.'];
        yield 'unknown option' => [true, 'XXL', 'Option "XXL" is not available for product %d.'];
        yield 'option on a single-price product' => [false, 'M', 'Product %d has no options.'];
    }

    private function createTestProductWithOptions(Restaurant $restaurant, Category $category): Product
    {
        $product = $this->createTestProduct($restaurant, $category);
        $product->setOptions([
            ['name' => 'M', 'price' => '12.000'],
            ['name' => 'Familiale', 'price' => '22.000'],
        ]);
        $product->setPrice('12.000');

        $this->entityManager->flush();

        return $product;
    }

    private function postOrder(KernelBrowser $client, string $token, Restaurant $restaurant, DeliveryZone $zone, array $items): array
    {
        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => $items,
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => $zone->getId(),
            ])
        );

        return json_decode($client->getResponse()->getContent(), true);
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

    /**
     * Guards against Money::toMillimes() * quantity overflowing into float
     * arithmetic — see OrderItemRequest.
     */
    public function testCreateOrderFailsWhenQuantityExceedsTheMax(): void
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
                        'quantity' => 101,
                    ],
                ],
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => 1,
            ])
        );

        self::assertResponseStatusCodeSame(422);
    }

    public function testCreateOrderFailsWhenTooManyLineItems(): void
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

        $items = array_fill(0, 51, [
            'productId' => $product->getId(),
            'quantity' => 1,
        ]);

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => $items,
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => 1,
            ])
        );

        self::assertResponseStatusCodeSame(422);
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

    public function testClientCanListOwnOrdersPaginated(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $otherUser = $this->createTestUser();

        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct($restaurant, $category);
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);

        // 3 orders of their own, plus one belonging to another user, which
        // must never appear in this user's list.
        for ($i = 0; $i < 3; ++$i) {
            $this->placeOrder($client, $token, $restaurant, $product, $zone);
        }
        $otherToken = $this->authenticateClient($client, $otherUser);
        $this->placeOrder($client, $otherToken, $restaurant, $product, $zone);

        $client->request(
            'GET',
            '/api/orders?page=1&limit=2',
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
        self::assertCount(2, $response['items']);
        self::assertSame([
            'page' => 1,
            'limit' => 2,
            'total' => 3,
            'pages' => 2,
        ], $response['meta']);

        $client->request(
            'GET',
            '/api/orders?page=2&limit=2',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertCount(1, $response['items']);
        self::assertSame(2, $response['meta']['page']);
    }

    /**
     * OrderService::getUserOrders used to lazy-load restaurant, deliveryZone,
     * delivery and items (plus each item's product) one query at a time per
     * row — for 3 orders that's ~15+ queries on top of the paginated SELECT
     * itself. It now eager-joins the to-one relations and batch-fetches
     * items in a single follow-up query (see OrderRepository::hydrateItems),
     * so the query count for this endpoint stays flat regardless of how many
     * orders are on the page. Counted via Doctrine's own debug middleware
     * (doctrine.debug_data_holder) rather than mocking anything, so this
     * fails for real if the eager-loading regresses.
     */
    public function testListingOrdersDoesNotIssueAQueryPerOrder(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct($restaurant, $category);
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);

        for ($i = 0; $i < 3; ++$i) {
            $this->placeOrder($client, $token, $restaurant, $product, $zone);
        }

        // Fetched fresh immediately before/after the request rather than
        // reused across it: the service is reset per-request (kernel.reset),
        // so a reference held from before the request can end up reading a
        // stale/replaced instance instead of the one that actually recorded
        // this request's queries.
        self::getContainer()->get('doctrine.debug_data_holder')->reset();

        $client->request(
            'GET',
            '/api/orders',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertCount(3, $response['items']);

        $queries = self::getContainer()->get('doctrine.debug_data_holder')->getData()['default'] ?? [];
        $queryCount = count($queries);

        // Sanity check first: a passing assertLessThanOrEqual below is
        // meaningless if the debug middleware silently recorded nothing.
        self::assertGreaterThan(
            0,
            $queryCount,
            'Expected doctrine.debug_data_holder to have recorded this request\'s queries.'
        );

        // Flat regardless of row count: reload the JWT's user, the
        // paginator's COUNT, the joined main SELECT, and the batch item
        // hydration — not one query per order. The unfixed version issued
        // 15+ queries for these same 3 orders.
        self::assertLessThanOrEqual(
            6,
            $queryCount,
            "Expected a small, constant number of queries regardless of order count, got {$queryCount}."
        );
    }

    public function testClientCanCancelAPendingOrder(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct($restaurant, $category);
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);

        $orderId = $this->placeOrderAndGetId($client, $token, $restaurant, $product, $zone);

        $client->request(
            'POST',
            "/api/orders/{$orderId}/cancel",
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(OrderStatus::CANCELLED->value, $response['status']);
        self::assertSame(DeliveryStatus::CANCELLED->value, $response['deliveryStatus']);
    }

    public function testClientCannotCancelAnotherUsersOrder(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $owner = $this->createTestUser();
        $intruder = $this->createTestUser();
        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct($restaurant, $category);
        $zone = $this->createTestDeliveryZone('4.000');

        $ownerToken = $this->authenticateClient($client, $owner);
        $orderId = $this->placeOrderAndGetId($client, $ownerToken, $restaurant, $product, $zone);

        $intruderToken = $this->authenticateClient($client, $intruder);

        $client->request(
            'POST',
            "/api/orders/{$orderId}/cancel",
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer ' . $intruderToken,
            ]
        );

        self::assertResponseStatusCodeSame(404);
    }

    public function testClientCannotCancelOnceCourierHasAccepted(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct($restaurant, $category);
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);
        $orderId = $this->placeOrderAndGetId($client, $token, $restaurant, $product, $zone);

        $courier = $this->createTestUser();
        $courier->setRoles(['ROLE_LIVREUR']);

        $delivery = $this->entityManager
            ->getRepository(\App\Entity\Delivery::class)
            ->findOneBy(['order' => $orderId]);

        self::assertNotNull($delivery);

        $delivery->setCourier($courier);
        $delivery->setStatus(DeliveryStatus::ACCEPTED);
        $this->entityManager->flush();

        $client->request(
            'POST',
            "/api/orders/{$orderId}/cancel",
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseStatusCodeSame(400);

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'This delivery cannot be cancelled at its current status.',
            $response['message']
        );
    }

    public function testOrderResponseIncludesAssignedCourierNameAndPhone(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();
        $restaurant = $this->createTestRestaurant();
        $category = $this->createTestCategory($restaurant);
        $product = $this->createTestProduct($restaurant, $category);
        $zone = $this->createTestDeliveryZone('4.000');

        $token = $this->authenticateClient($client, $user);
        $orderId = $this->placeOrderAndGetId($client, $token, $restaurant, $product, $zone);

        $courier = $this->createTestUser();
        $courier->setRoles(['ROLE_LIVREUR']);
        $courier->setName('Sami Courier');

        $delivery = $this->entityManager
            ->getRepository(\App\Entity\Delivery::class)
            ->findOneBy(['order' => $orderId]);

        self::assertNotNull($delivery);

        $delivery->setCourier($courier);
        $delivery->setStatus(DeliveryStatus::ASSIGNED);
        $this->entityManager->flush();

        $client->request(
            'GET',
            "/api/orders/{$orderId}",
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame('Sami Courier', $response['courierName']);
        self::assertSame($courier->getPhone(), $response['courierPhone']);
        self::assertSame(DeliveryStatus::ASSIGNED->value, $response['deliveryStatus']);
    }

    private function placeOrderAndGetId(
        KernelBrowser $client,
        string $token,
        Restaurant $restaurant,
        Product $product,
        DeliveryZone $zone,
    ): int {
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

        self::assertResponseStatusCodeSame(201);

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        return $response['id'];
    }

    private function placeOrder(
        KernelBrowser $client,
        string $token,
        Restaurant $restaurant,
        Product $product,
        DeliveryZone $zone,
    ): void {
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

        self::assertResponseStatusCodeSame(201);
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
        bool $available = true,
        RestaurantType $type = RestaurantType::RESTAURANT,
    ): Restaurant {
        $restaurant = new Restaurant();

        $restaurant->setName(
            'Test Restaurant ' . random_int(1000, 9999)
        );

        $restaurant->setIsAvailable($available);
        $restaurant->setType($type);

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

        // A 4-digit range (9000 values) collides often enough across a
        // 185+ test suite creating dozens of zones per run to fail CI on
        // the unique name constraint — seen in practice, not theoretical.
        $zone->setName('Test Zone '.random_int(1000000, 999999999));
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
