<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\Delivery;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\OrderItem;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\OrderStatus;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;

final class DeliveryApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function testAdminCanAssignDeliveryToCourier(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Test Courier'
        );

        $delivery = $this->createTestDelivery();

        $token = $this->authenticateClient($client, $admin);

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $delivery->getId(),
                $courier->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);

        self::assertSame(
            $delivery->getId(),
            $response['id']
        );

        self::assertSame(
            DeliveryStatus::ASSIGNED->value,
            $response['status']
        );

        self::assertSame(
            $courier->getId(),
            $response['courierId']
        );

        self::assertNotNull(
            $response['assignedAt']
        );

        $this->entityManager->clear();

        $savedDelivery = $this->entityManager
            ->getRepository(Delivery::class)
            ->find($delivery->getId());

        self::assertNotNull($savedDelivery);

        self::assertSame(
            DeliveryStatus::ASSIGNED,
            $savedDelivery->getStatus()
        );

        self::assertNotNull(
            $savedDelivery->getCourier()
        );

        self::assertSame(
            $courier->getId(),
            $savedDelivery->getCourier()->getId()
        );

        self::assertSame(
            OrderStatus::CONFIRMED,
            $savedDelivery->getOrder()->getStatus()
        );
    }

    /**
     * DeliveryStatusChangedEvent → DeliveryNotificationListener →
     * PushNotificationService fires on every assign, but with no
     * FIREBASE_CREDENTIALS configured in the test env it must stay a no-op
     * rather than blocking or failing the assignment itself — this is the
     * concrete proof of that contract, not just an absence of a crash.
     */
    public function testAssigningADeliveryStillSucceedsWhenCourierHasARegisteredDeviceToken(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');
        $courier = $this->createTestUser('ROLE_LIVREUR', 'Notified Courier');
        $delivery = $this->createTestDelivery();

        $courierToken = $this->authenticateClient($client, $courier);

        $client->request(
            'POST',
            '/api/notifications/device-token',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$courierToken,
            ],
            content: json_encode(['token' => 'fcm-token-'.bin2hex(random_bytes(16))])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'POST',
            sprintf('/api/deliveries/%d/assign/%d', $delivery->getId(), $courier->getId()),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
    }

    public function testNonAdminCannotAssignDelivery(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Test Courier'
        );

        $delivery = $this->createTestDelivery();

        $token = $this->authenticateClient(
            $client,
            $clientUser
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $delivery->getId(),
                $courier->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testAdminCannotAssignDeliveryToNonCourier(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $delivery = $this->createTestDelivery();

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $delivery->getId(),
                $clientUser->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_BAD_REQUEST
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'The selected user is not a courier.',
            $response['message']
        );
    }

    public function testAdminCannotAssignDeliveryToDeactivatedCourier(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Deactivated Courier'
        );

        $courier->setActive(false);

        $this->entityManager->flush();

        $delivery = $this->createTestDelivery();

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $delivery->getId(),
                $courier->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_BAD_REQUEST
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'This courier has been deactivated.',
            $response['message']
        );
    }

    public function testCourierCanCompleteDeliveryLifecycle(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Test Courier'
        );

        $delivery = $this->createTestDelivery();

        $orderId = $delivery->getOrder()?->getId();

        self::assertNotNull($orderId);

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        // PENDING -> ASSIGNED
        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $delivery->getId(),
                $courier->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            DeliveryStatus::ASSIGNED->value,
            $response['status']
        );

        $this->assertOrderStatus(
            $orderId,
            OrderStatus::CONFIRMED
        );

        $courierToken = $this->authenticateClient(
            $client,
            $courier
        );

        // ASSIGNED -> ACCEPTED
        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/accept',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $courierToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            DeliveryStatus::ACCEPTED->value,
            $response['status']
        );

        self::assertNotNull(
            $response['acceptedAt']
        );

        $this->assertOrderStatus(
            $orderId,
            OrderStatus::CONFIRMED
        );

        // ACCEPTED -> PICKED_UP
        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/pickup',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $courierToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            DeliveryStatus::PICKED_UP->value,
            $response['status']
        );

        self::assertNotNull(
            $response['pickedUpAt']
        );

        $this->assertOrderStatus(
            $orderId,
            OrderStatus::READY_FOR_PICKUP
        );

        // PICKED_UP -> ON_THE_WAY
        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/on-the-way',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $courierToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            DeliveryStatus::ON_THE_WAY->value,
            $response['status']
        );

        $this->assertOrderStatus(
            $orderId,
            OrderStatus::READY_FOR_PICKUP
        );

        // ON_THE_WAY -> DELIVERED
        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/delivered',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $courierToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            DeliveryStatus::DELIVERED->value,
            $response['status']
        );

        self::assertNotNull(
            $response['deliveredAt']
        );

        $this->assertOrderStatus(
            $orderId,
            OrderStatus::COMPLETED
        );
    }

    public function testWrongCourierCannotAcceptDelivery(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Assigned Courier'
        );

        $otherCourier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Other Courier'
        );

        $delivery = $this->createTestDelivery();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $delivery->getId(),
                $courier->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $otherCourierToken = $this->authenticateClient(
            $client,
            $otherCourier
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/accept',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $otherCourierToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_BAD_REQUEST
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'You are not assigned to this delivery.',
            $response['message']
        );
    }

    public function testCourierCannotAcceptPendingDelivery(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Test Courier'
        );

        $delivery = $this->createTestDelivery();

        $token = $this->authenticateClient(
            $client,
            $courier
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/accept',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_BAD_REQUEST
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'Only assigned deliveries can be accepted.',
            $response['message']
        );

        $this->assertOrderStatus(
            $delivery->getOrder()->getId(),
            OrderStatus::PENDING
        );
    }

    public function testCourierCanListOwnDeliveries(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Test Courier'
        );

        $otherCourier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Other Courier'
        );

        $delivery = $this->createTestDelivery();
        $otherDelivery = $this->createTestDelivery();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $delivery->getId(),
                $courier->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $otherDelivery->getId(),
                $otherCourier->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $courierToken = $this->authenticateClient(
            $client,
            $courier
        );

        $client->request(
            'GET',
            '/api/deliveries/mine',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer ' . $courierToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);
        self::assertCount(1, $response['items']);

        self::assertSame(
            $delivery->getId(),
            $response['items'][0]['id']
        );

        self::assertSame(
            $courier->getId(),
            $response['items'][0]['courierId']
        );

        // The courier needs the pickup/drop-off details, not just an order id.
        $order = $response['items'][0]['order'];

        self::assertIsArray($order);
        self::assertSame($delivery->getOrder()->getId(), $order['id']);
        self::assertSame('Tunis, Tunisia', $order['deliveryAddress']);
        self::assertSame('Delivery Test Client', $order['customerName']);
        self::assertNotEmpty($order['customerPhone']);
        self::assertNotEmpty($order['restaurantName']);
        self::assertCount(1, $order['items']);
        self::assertSame(1, $order['items'][0]['quantity']);
        self::assertSame('12.500', $order['items'][0]['unitPrice']);
    }

    public function testClientCannotAccessCourierDeliveries(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $token = $this->authenticateClient(
            $client,
            $clientUser
        );

        $client->request(
            'GET',
            '/api/deliveries/mine',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testAdminCanCancelPendingDelivery(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $delivery = $this->createTestDelivery();

        $orderId = $delivery->getOrder()->getId();

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/cancel',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            DeliveryStatus::CANCELLED->value,
            $response['status']
        );

        $this->assertOrderStatus(
            $orderId,
            OrderStatus::CANCELLED
        );
    }

    public function testCourierCanDeclineAssignedDelivery(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Test Courier'
        );

        $delivery = $this->createTestDelivery();

        $orderId = $delivery->getOrder()->getId();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $delivery->getId(),
                $courier->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $courierToken = $this->authenticateClient(
            $client,
            $courier
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/decline',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $courierToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            DeliveryStatus::PENDING->value,
            $response['status']
        );

        self::assertNull(
            $response['courierId']
        );

        $this->assertOrderStatus(
            $orderId,
            OrderStatus::PENDING
        );
    }

    public function testCourierCannotDeclineDeliveryAssignedToSomeoneElse(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Assigned Courier'
        );

        $otherCourier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Other Courier'
        );

        $delivery = $this->createTestDelivery();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $delivery->getId(),
                $courier->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $otherCourierToken = $this->authenticateClient(
            $client,
            $otherCourier
        );

        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/decline',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $otherCourierToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_BAD_REQUEST
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'You are not assigned to this delivery.',
            $response['message']
        );
    }

    public function testCourierCanFailAcceptedDelivery(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Test Courier'
        );

        $delivery = $this->createTestDelivery();

        $orderId = $delivery->getOrder()->getId();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        // PENDING -> ASSIGNED
        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/assign/%d',
                $delivery->getId(),
                $courier->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $courierToken = $this->authenticateClient(
            $client,
            $courier
        );

        // ASSIGNED -> ACCEPTED
        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/accept',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $courierToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        self::assertSame(
            OrderStatus::CONFIRMED,
            $this->getOrder($orderId)->getStatus()
        );

        // ACCEPTED -> FAILED
        $client->request(
            'POST',
            sprintf(
                '/api/deliveries/%d/fail',
                $delivery->getId()
            ),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $courierToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            DeliveryStatus::FAILED->value,
            $response['status']
        );

        $this->assertOrderStatus(
            $orderId,
            OrderStatus::CANCELLED
        );
    }

    private function createTestDelivery(): Delivery
    {
        $restaurant = new Restaurant();

        $restaurant->setName(
            'Test Restaurant ' . random_int(1000, 9999)
        );

        $restaurant->setIsAvailable(true);

        $category = new Category();

        $category->setName(
            'Test Category ' . random_int(1000, 9999)
        );

        $category->setRestaurant($restaurant);

        $product = new Product();

        $product->setName(
            'Test Product ' . random_int(1000, 9999)
        );

        $product->setPrice('12.500');
        $product->setIsAvailable(true);
        $product->setRestaurant($restaurant);
        $product->setCategory($category);

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Delivery Test Client'
        );

        $deliveryZone = new DeliveryZone();

        $deliveryZone->setName('Test Zone '.random_int(1000, 9999));
        $deliveryZone->setFee('4.000');

        $order = new Order();

        $order->setUser($clientUser);
        $order->setRestaurant($restaurant);
        $order->setNote('Delivery integration test');
        $order->setDeliveryAddress('Tunis, Tunisia');
        $order->setDeliveryZone($deliveryZone);
        $order->setDeliveryFee('4.000');
        $order->setTotalAmount('16.500');
        $order->setStatus(OrderStatus::PENDING);

        $orderItem = new OrderItem();

        $orderItem->setProduct($product);
        $orderItem->setQuantity(1);
        $orderItem->setUnitPrice('12.500');

        $order->addItem($orderItem);

        $delivery = new Delivery();

        $delivery->setOrder($order);
        $delivery->setStatus(DeliveryStatus::PENDING);

        $order->setDelivery($delivery);

        $this->entityManager->persist($restaurant);
        $this->entityManager->persist($category);
        $this->entityManager->persist($product);
        $this->entityManager->persist($deliveryZone);
        $this->entityManager->persist($order);
        $this->entityManager->persist($delivery);

        $this->entityManager->flush();

        return $delivery;
    }

    private function createTestUser(
        string $role,
        string $name
    ): User {
        $phone = '2' . random_int(10000000, 99999999);

        $user = new User();

        $user->setName($name);
        $user->setPhone($phone);
        $user->setRoles([$role]);
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

    private function getOrder(int $orderId): Order
    {
        $this->entityManager->clear();

        $order = $this->entityManager
            ->getRepository(Order::class)
            ->find($orderId);

        self::assertNotNull($order);

        return $order;
    }

    private function assertOrderStatus(
        int $orderId,
        OrderStatus $expectedStatus
    ): void {
        $order = $this->getOrder($orderId);

        self::assertSame(
            $expectedStatus,
            $order->getStatus()
        );
    }
}