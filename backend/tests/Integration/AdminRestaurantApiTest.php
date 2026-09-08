<?php

namespace App\Tests\Integration;

use App\Entity\Restaurant;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;

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

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/restaurants',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Test Restaurant',
                'description' => 'Test description',
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
        self::assertSame('Test Restaurant', $response['name']);
        self::assertSame('Test description', $response['description']);
        self::assertTrue($response['isAvailable']);

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
            'Test description',
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

        $user = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'POST',
            '/api/admin/restaurants',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Unauthorized Restaurant',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testAdminCannotCreateRestaurantWithInvalidData(): void
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
            'POST',
            '/api/admin/restaurants',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => '',
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
            'Validation failed',
            $response['error']
        );

        self::assertArrayHasKey(
            'name',
            $response['fields']
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

        $this->createRestaurant(
            'Restaurant A',
            'Description A',
            true
        );

        $this->createRestaurant(
            'Restaurant B',
            'Description B',
            false
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/restaurants',
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
        self::assertCount(2, $response);
    }

    public function testAdminCanShowRestaurant(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Show Restaurant',
            'Show description',
            true
        );

        $restaurantId = $restaurant->getId();

        $this->entityManager->clear();

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/restaurants/'.$restaurantId,
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

        self::assertSame(
            'Show Restaurant',
            $response['name']
        );
        self::assertSame(
            'Show description',
            $response['description']
        );
        self::assertTrue(
            $response['isAvailable']
        );
    }

    public function testAdminGets404ForUnknownRestaurant(): void
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
            '/api/admin/restaurants/999999',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testAdminCanUpdateRestaurant(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Old Name',
            'Old description',
            true
        );

        $restaurantId = $restaurant->getId();

        $this->entityManager->clear();

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PUT',
            '/api/admin/restaurants/'.$restaurantId,
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'New Name',
                'description' => 'New description',
                'isAvailable' => false,
            ])
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
            'New Name',
            $response['name']
        );
        self::assertSame(
            'New description',
            $response['description']
        );
        self::assertFalse(
            $response['isAvailable']
        );

        $this->entityManager->clear();

        $updatedRestaurant = $this->entityManager
            ->getRepository(Restaurant::class)
            ->find($restaurantId);

        self::assertNotNull($updatedRestaurant);
        self::assertSame(
            'New Name',
            $updatedRestaurant->getName()
        );
        self::assertSame(
            'New description',
            $updatedRestaurant->getDescription()
        );
        self::assertFalse(
            $updatedRestaurant->isAvailable()
        );
    }

    public function testAdminCanChangeAvailability(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Availability Restaurant',
            null,
            true
        );

        $restaurantId = $restaurant->getId();

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PATCH',
            '/api/admin/restaurants/'.$restaurantId.'/availability',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'isAvailable' => false,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);

        self::assertFalse(
            $response['isAvailable']
        );

        $this->entityManager->clear();

        $updatedRestaurant = $this->entityManager
            ->getRepository(Restaurant::class)
            ->find($restaurantId);

        self::assertNotNull($updatedRestaurant);
        self::assertFalse(
            $updatedRestaurant->isAvailable()
        );
    }

    private function createRestaurant(
        string $name,
        ?string $description,
        bool $isAvailable
    ): Restaurant {
        $restaurant = new Restaurant();

        $restaurant
            ->setName($name)
            ->setDescription($description)
            ->setIsAvailable($isAvailable);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        return $restaurant;
    }

    private function createTestUser(
        string $role,
        string $name
    ): User {
        $user = new User();

        $user
            ->setName($name)
            ->setPhone($this->uniquePhone())
            ->setRoles([$role]);

        $hasher = self::getContainer()
            ->get(UserPasswordHasherInterface::class);

        $user->setPassword(
            $hasher->hashPassword($user, 'password123')
        );

        $user->setVerifiedAt(
            new \DateTimeImmutable()
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

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);
        self::assertArrayHasKey(
            'token',
            $response
        );

        return $response['token'];
    }

    private function uniquePhone(): string
    {
        return '9'.random_int(
            10000000,
            99999999
        );
    }
}