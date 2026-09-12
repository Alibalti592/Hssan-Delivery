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
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class AdminDeliveryApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    protected function tearDown(): void
    {
        if (isset($this->entityManager)) {
            // Deleted in dependency order so this doesn't trip a foreign
            // key violation, and so other tests' own cleanup queries don't
            // trip over rows left behind here.
            $this->entityManager->createQuery('DELETE FROM App\Entity\Delivery d')->execute();
            $this->entityManager->createQuery('DELETE FROM App\Entity\OrderItem oi')->execute();
            $this->entityManager->createQuery('DELETE FROM App\Entity\Order o')->execute();
            $this->entityManager->createQuery('DELETE FROM App\Entity\Product p')->execute();
            $this->entityManager->createQuery('DELETE FROM App\Entity\Category c')->execute();
            $this->entityManager->createQuery('DELETE FROM App\Entity\Restaurant r')->execute();
            $this->entityManager->createQuery('DELETE FROM App\Entity\DeliveryZone z')->execute();

            $this->entityManager->clear();
        }

        parent::tearDown();
    }

    public function testAdminCanListDeliveries(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $delivery = $this->createTestDelivery();

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/deliveries',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
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

        $ids = array_column($response['items'], 'id');

        self::assertContains($delivery->getId(), $ids);
    }

    public function testNonAdminCannotListDeliveries(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'GET',
            '/api/admin/deliveries',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testAdminCanShowDelivery(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $delivery = $this->createTestDelivery();

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/deliveries/'.$delivery->getId(),
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
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

        self::assertSame($delivery->getId(), $response['id']);
        self::assertSame(DeliveryStatus::PENDING->value, $response['status']);
        self::assertSame(
            $delivery->getOrder()->getId(),
            $response['orderId']
        );
    }

    public function testAdminGets404ForUnknownDelivery(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/deliveries/999999',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testNonAdminCannotShowDelivery(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $delivery = $this->createTestDelivery();

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'GET',
            '/api/admin/deliveries/'.$delivery->getId(),
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    private function createTestDelivery(): Delivery
    {
        $restaurant = new Restaurant();

        $restaurant->setName('Test Restaurant '.random_int(1000, 9999));
        $restaurant->setIsAvailable(true);

        $category = new Category();

        $category->setName('Test Category '.random_int(1000, 9999));
        $category->setRestaurant($restaurant);

        $product = new Product();

        $product->setName('Test Product '.random_int(1000, 9999));
        $product->setPrice('12.500');
        $product->setIsAvailable(true);
        $product->setRestaurant($restaurant);
        $product->setCategory($category);

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Delivery Admin Test Client'
        );

        $deliveryZone = new DeliveryZone();

        $deliveryZone->setName('Test Zone '.random_int(1000, 9999));
        $deliveryZone->setFee('4.000');

        $order = new Order();

        $order->setUser($clientUser);
        $order->setRestaurant($restaurant);
        $order->setNote('Admin delivery test');
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
        string $name,
    ): User {
        $user = new User();

        $user->setName($name);
        $user->setPhone($this->uniquePhone());
        $user->setRoles([$role]);
        $user->setVerifiedAt(
            new \DateTimeImmutable()
        );

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
        User $user,
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

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

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

    private function uniquePhone(): string
    {
        return '6'.random_int(
            10000000,
            99999999
        );
    }
}
