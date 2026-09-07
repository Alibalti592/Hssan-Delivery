<?php

namespace App\Tests\Integration;

use App\Entity\Restaurant;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class AdminRestaurantApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    public function testAdminCanCreateRestaurant(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/restaurants',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'name' => 'Test Restaurant',
                'description' => 'A test restaurant',
                'isAvailable' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_CREATED
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);

        self::assertArrayHasKey('id', $response);

        self::assertSame(
            'Test Restaurant',
            $response['name']
        );

        self::assertSame(
            'A test restaurant',
            $response['description']
        );

        self::assertTrue(
            $response['isAvailable']
        );

        self::assertArrayHasKey(
            'createdAt',
            $response
        );

        self::assertArrayHasKey(
            'updatedAt',
            $response
        );

        $this->entityManager->clear();

        $restaurant = $this->entityManager
            ->getRepository(Restaurant::class)
            ->find($response['id']);

        self::assertNotNull($restaurant);

        self::assertSame(
            'Test Restaurant',
            $restaurant->getName()
        );

        self::assertSame(
            'A test restaurant',
            $restaurant->getDescription()
        );

        self::assertTrue(
            $restaurant->isAvailable()
        );
    }

    public function testNonAdminCannotCreateRestaurant(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $clientUser
        );

        $client->request(
            'POST',
            '/api/admin/restaurants',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'name' => 'Unauthorized Restaurant',
                'description' => 'Should not be created',
                'isAvailable' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );

        $restaurant = $this->entityManager
            ->getRepository(Restaurant::class)
            ->findOneBy([
                'name' => 'Unauthorized Restaurant',
            ]);

        self::assertNull($restaurant);
    }

    public function testInvalidRestaurantDataIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/restaurants',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'name' => '',
                'description' => 'Invalid restaurant',
                'isAvailable' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNPROCESSABLE_ENTITY
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);

        self::assertSame(
            'Validation failed.',
            $response['message']
        );

        self::assertArrayHasKey(
            'errors',
            $response
        );
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
        return '2'.random_int(
            10000000,
            99999999
        );
    }

    public function testAdminCanListRestaurants(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurantOne = (new Restaurant())
            ->setName('Restaurant One')
            ->setDescription('First restaurant')
            ->setIsAvailable(true);

        $restaurantTwo = (new Restaurant())
            ->setName('Restaurant Two')
            ->setDescription('Second restaurant')
            ->setIsAvailable(false);

        $this->entityManager->persist($restaurantOne);
        $this->entityManager->persist($restaurantTwo);
        $this->entityManager->flush();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/restaurants',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);

        $names = array_column($response, 'name');

        self::assertContains('Restaurant One', $names);
        self::assertContains('Restaurant Two', $names);
    }

    public function testNonAdminCannotListRestaurants(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'GET',
            '/api/admin/restaurants',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testAdminGetsEmptyRestaurantList(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $this->entityManager
            ->createQuery('DELETE FROM App\Entity\Restaurant r')
            ->execute();

        $this->entityManager->clear();

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/restaurants',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame([], $response);
    }
}
