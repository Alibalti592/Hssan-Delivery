<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\Restaurant;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class AdminCategoryApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    public function testAdminCanCreateCategory(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Test Restaurant'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurant->getId().'/categories',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'name' => 'Burgers',
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
        self::assertSame('Burgers', $response['name']);
        self::assertSame(
            $restaurant->getId(),
            $response['restaurantId']
        );

        $this->entityManager->clear();

        $category = $this->entityManager
            ->getRepository(Category::class)
            ->find($response['id']);

        self::assertNotNull($category);
        self::assertSame(
            'Burgers',
            $category->getName()
        );
        self::assertNotNull(
            $category->getRestaurant()
        );
        self::assertSame(
            $restaurant->getId(),
            $category->getRestaurant()->getId()
        );
    }

    public function testNonAdminCannotCreateCategory(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $restaurant = $this->createRestaurant(
            'Test Restaurant'
        );

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurant->getId().'/categories',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Unauthorized Category',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testInvalidCategoryDataIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Test Restaurant'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurant->getId().'/categories',
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
            'Validation failed.',
            $response['message']
        );

        self::assertArrayHasKey(
            'errors',
            $response
        );
    }

    public function testCreatingCategoryWithUnknownRestaurantReturns404(): void
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
            '/api/admin/restaurants/999999/categories',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Burgers',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testAdminCanListCategoriesForRestaurant(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Test Restaurant'
        );

        $this->createCategory(
            $restaurant,
            'Burgers'
        );

        $this->createCategory(
            $restaurant,
            'Drinks'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/restaurants/'.$restaurant->getId().'/categories',
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

        self::assertCount(
            2,
            $response
        );

        $names = array_column(
            $response,
            'name'
        );

        self::assertContains(
            'Burgers',
            $names
        );

        self::assertContains(
            'Drinks',
            $names
        );
    }

    public function testAdminGetsEmptyCategoryList(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Empty Restaurant'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/restaurants/'.$restaurant->getId().'/categories',
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

        self::assertSame(
            [],
            $response
        );
    }

    public function testAdminCanShowCategory(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Test Restaurant'
        );

        $category = $this->createCategory(
            $restaurant,
            'Desserts'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/categories/'.$category->getId(),
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
            $category->getId(),
            $response['id']
        );

        self::assertSame(
            'Desserts',
            $response['name']
        );

        self::assertSame(
            $restaurant->getId(),
            $response['restaurantId']
        );
    }

    public function testAdminGets404ForUnknownCategory(): void
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
            '/api/admin/categories/999999',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testAdminCanUpdateCategory(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Test Restaurant'
        );

        $category = $this->createCategory(
            $restaurant,
            'Old Name'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PUT',
            '/api/admin/categories/'.$category->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'New Name',
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

        $this->entityManager->clear();

        $updatedCategory = $this->entityManager
            ->getRepository(Category::class)
            ->find($category->getId());

        self::assertNotNull($updatedCategory);

        self::assertSame(
            'New Name',
            $updatedCategory->getName()
        );

        self::assertSame(
            $restaurant->getId(),
            $updatedCategory->getRestaurant()?->getId()
        );
    }

    public function testInvalidCategoryUpdateIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Test Restaurant'
        );

        $category = $this->createCategory(
            $restaurant,
            'Valid Name'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PUT',
            '/api/admin/categories/'.$category->getId(),
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
    }

    public function testNonAdminCannotUpdateCategory(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $restaurant = $this->createRestaurant(
            'Test Restaurant'
        );

        $category = $this->createCategory(
            $restaurant,
            'Protected Category'
        );

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'PUT',
            '/api/admin/categories/'.$category->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Hacked Category',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    private function createRestaurant(string $name): Restaurant
    {
        $restaurant = (new Restaurant())
            ->setName($name)
            ->setDescription(null)
            ->setIsAvailable(true);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        return $restaurant;
    }

    private function createCategory(
        Restaurant $restaurant,
        string $name,
    ): Category {
        $category = (new Category())
            ->setName($name)
            ->setRestaurant($restaurant);

        $this->entityManager->persist($category);
        $this->entityManager->flush();

        return $category;
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
        return '3'.random_int(
            10000000,
            99999999
        );
    }
}