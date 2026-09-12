<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\OrderStatus;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class AdminStatsApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    /**
     * The suite shares one Postgres database across every test file (no
     * per-test transaction/rollback), so this asserts the *delta* caused by
     * data this test creates rather than an absolute count — matching the
     * same baseline-diff approach used in AdminCourierApiTest's pagination
     * test, for the same reason.
     */
    public function testAdminCanSeeStatsSummary(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');
        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'GET',
            '/api/admin/stats',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $baseline = json_decode($client->getResponse()->getContent(), true);

        self::assertIsArray($baseline);
        self::assertArrayHasKey('restaurants', $baseline);
        self::assertArrayHasKey('deliveryZones', $baseline);
        self::assertArrayHasKey('couriers', $baseline);
        self::assertArrayHasKey('totalOrders', $baseline);
        self::assertArrayHasKey('activeOrders', $baseline);

        // One completed order (must NOT count as active) and one still
        // pending (must count as active).
        $this->createTestUser('ROLE_LIVREUR', 'Stats Courier');
        $restaurant = $this->createRestaurant();
        $zone = $this->createZone();
        $this->createOrder($client, $restaurant, $zone, 'PENDING');
        $this->createOrder($client, $restaurant, $zone, 'COMPLETED');

        $client->request(
            'GET',
            '/api/admin/stats',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken]
        );

        $after = json_decode($client->getResponse()->getContent(), true);

        self::assertSame($baseline['restaurants'] + 1, $after['restaurants']);
        self::assertSame($baseline['deliveryZones'] + 1, $after['deliveryZones']);
        self::assertSame($baseline['couriers'] + 1, $after['couriers']);
        self::assertSame($baseline['totalOrders'] + 2, $after['totalOrders']);
        self::assertSame($baseline['activeOrders'] + 1, $after['activeOrders']);
    }

    public function testNonAdminCannotSeeStats(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_USER', 'Test Client');
        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/admin/stats',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);
    }

    private function createRestaurant(): Restaurant
    {
        $restaurant = (new Restaurant())
            ->setName('Stats Restaurant '.random_int(1000, 9999))
            ->setIsAvailable(true);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        return $restaurant;
    }

    private function createZone(): DeliveryZone
    {
        $zone = (new DeliveryZone())
            ->setName('Stats Zone '.random_int(1000, 9999))
            ->setFee('4.000');

        $this->entityManager->persist($zone);
        $this->entityManager->flush();

        return $zone;
    }

    private function createOrder(
        KernelBrowser $client,
        Restaurant $restaurant,
        DeliveryZone $zone,
        string $status,
    ): void {
        $category = (new Category())
            ->setName('Stats Category '.random_int(1000, 9999))
            ->setRestaurant($restaurant);

        $product = (new Product())
            ->setName('Stats Product '.random_int(1000, 9999))
            ->setPrice('10.000')
            ->setIsAvailable(true)
            ->setRestaurant($restaurant)
            ->setCategory($category);

        $this->entityManager->persist($category);
        $this->entityManager->persist($product);
        $this->entityManager->flush();

        $customer = $this->createTestUser('ROLE_USER', 'Stats Client '.random_int(1000, 9999));

        $token = $this->authenticateClient($client, $customer);

        $client->request(
            'POST',
            '/api/orders',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'restaurantId' => $restaurant->getId(),
                'items' => [['productId' => $product->getId(), 'quantity' => 1]],
                'deliveryAddress' => 'Tunis, Tunisia',
                'deliveryZoneId' => $zone->getId(),
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);

        $orderId = json_decode($client->getResponse()->getContent(), true)['id'];

        if ('COMPLETED' === $status) {
            $order = $this->entityManager->getRepository(Order::class)->find($orderId);
            $order->setStatus(OrderStatus::COMPLETED);
            $this->entityManager->flush();
        }
    }

    private function createTestUser(
        string $role,
        string $name,
    ): User {
        $user = new User();

        $user->setName($name);
        $user->setPhone($this->uniquePhone());
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());

        $passwordHasher = self::getContainer()
            ->get(UserPasswordHasherInterface::class);

        $user->setPassword(
            $passwordHasher->hashPassword($user, 'password123')
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
            server: ['CONTENT_TYPE' => 'application/json'],
            content: json_encode([
                'phone' => $user->getPhone(),
                'password' => 'password123',
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $loginData = json_decode($client->getResponse()->getContent(), true);

        return $loginData['token'];
    }

    private function uniquePhone(): string
    {
        return '2'.random_int(10000000, 99999999);
    }
}
