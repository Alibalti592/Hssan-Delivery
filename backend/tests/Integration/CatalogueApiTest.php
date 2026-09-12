<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class CatalogueApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    public function testClientCanListOnlyAvailableRestaurants(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $customer = $this->createTestUser('ROLE_CLIENT', 'Test Client');

        $open = $this->createRestaurant('Open Diner', true);
        $this->createRestaurant('Closed Diner', false);

        $token = $this->authenticateClient($client, $customer);

        $client->request(
            'GET',
            '/api/restaurants',
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

        $names = array_column($response['items'], 'name');

        self::assertContains('Open Diner', $names);
        self::assertNotContains('Closed Diner', $names);

        $listed = current(array_filter(
            $response['items'],
            static fn ($r) => $r['id'] === $open->getId()
        ));

        self::assertArrayHasKey('photoUrl', $listed);
        self::assertArrayHasKey('isAvailable', $listed);
    }

    public function testUnauthenticatedRequestIsRejected(): void
    {
        $client = static::createClient();

        $client->request('GET', '/api/restaurants');

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNAUTHORIZED
        );
    }

    public function testCourierCanAlsoBrowseTheCatalogue(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $courier = $this->createTestUser('ROLE_LIVREUR', 'Test Courier');

        $this->createRestaurant('Courier Visible Diner', true);

        $token = $this->authenticateClient($client, $courier);

        $client->request(
            'GET',
            '/api/restaurants',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );
    }

    public function testClientCanShowAnAvailableRestaurant(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $customer = $this->createTestUser('ROLE_CLIENT', 'Test Client');

        $restaurant = $this->createRestaurant('Showable Diner', true);

        $token = $this->authenticateClient($client, $customer);

        $client->request(
            'GET',
            '/api/restaurants/'.$restaurant->getId(),
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

        self::assertSame('Showable Diner', $response['name']);
    }

    public function testShowingAClosedRestaurantReturns404(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $customer = $this->createTestUser('ROLE_CLIENT', 'Test Client');

        $restaurant = $this->createRestaurant('Hidden Diner', false);

        $token = $this->authenticateClient($client, $customer);

        $client->request(
            'GET',
            '/api/restaurants/'.$restaurant->getId(),
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testShowingAnUnknownRestaurantReturns404(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $customer = $this->createTestUser('ROLE_CLIENT', 'Test Client');

        $token = $this->authenticateClient($client, $customer);

        $client->request(
            'GET',
            '/api/restaurants/999999',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testClientCanListCategoriesForAnAvailableRestaurant(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $customer = $this->createTestUser('ROLE_CLIENT', 'Test Client');

        $restaurant = $this->createRestaurant('Category Diner', true);
        $this->createCategory($restaurant, 'Burgers');

        $token = $this->authenticateClient($client, $customer);

        $client->request(
            'GET',
            '/api/restaurants/'.$restaurant->getId().'/categories',
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

        self::assertCount(1, $response);
        self::assertSame('Burgers', $response[0]['name']);
    }

    public function testListingCategoriesForAClosedRestaurantReturns404(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $customer = $this->createTestUser('ROLE_CLIENT', 'Test Client');

        $restaurant = $this->createRestaurant('Closed Category Diner', false);

        $token = $this->authenticateClient($client, $customer);

        $client->request(
            'GET',
            '/api/restaurants/'.$restaurant->getId().'/categories',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testClientSeesOnlyAvailableProducts(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $customer = $this->createTestUser('ROLE_CLIENT', 'Test Client');

        $restaurant = $this->createRestaurant('Product Diner', true);
        $category = $this->createCategory($restaurant, 'Burgers');

        $this->createProduct($restaurant, $category, 'Available Burger', '12.500', true);
        $this->createProduct($restaurant, $category, 'Sold Out Burger', '13.500', false);

        $token = $this->authenticateClient($client, $customer);

        $client->request(
            'GET',
            '/api/restaurants/'.$restaurant->getId().'/products',
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

        $names = array_column($response['items'], 'name');

        self::assertContains('Available Burger', $names);
        self::assertNotContains('Sold Out Burger', $names);
    }

    public function testListingProductsForAClosedRestaurantReturns404(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $customer = $this->createTestUser('ROLE_CLIENT', 'Test Client');

        $restaurant = $this->createRestaurant('Closed Product Diner', false);

        $token = $this->authenticateClient($client, $customer);

        $client->request(
            'GET',
            '/api/restaurants/'.$restaurant->getId().'/products',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    private function createRestaurant(string $name, bool $isAvailable): Restaurant
    {
        $restaurant = (new Restaurant())
            ->setName($name)
            ->setDescription(null)
            ->setIsAvailable($isAvailable);

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

    private function createProduct(
        Restaurant $restaurant,
        Category $category,
        string $name,
        string $price,
        bool $isAvailable,
    ): Product {
        $product = (new Product())
            ->setName($name)
            ->setDescription(null)
            ->setPrice($price)
            ->setIsAvailable($isAvailable)
            ->setRestaurant($restaurant)
            ->setCategory($category);

        $this->entityManager->persist($product);
        $this->entityManager->flush();

        return $product;
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
        return '2'.random_int(10000000, 99999999);
    }
}
