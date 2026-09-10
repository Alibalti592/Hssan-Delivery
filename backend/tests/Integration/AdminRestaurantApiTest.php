<?php

namespace App\Tests\Integration;

use App\Entity\Restaurant;
use App\Entity\User;
use App\Entity\Category;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\Product;
use App\Enum\OrderStatus;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\File\UploadedFile;
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

    public function testAdminCanDeleteRestaurantWithoutOrders(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = (new Restaurant())
            ->setName('Deletable Restaurant')
            ->setDescription(null)
            ->setIsAvailable(true);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        $category = (new Category())
            ->setName('Deletable Category')
            ->setRestaurant($restaurant);

        $this->entityManager->persist($category);

        $product = (new Product())
            ->setName('Deletable Product')
            ->setPrice('10.000')
            ->setIsAvailable(true)
            ->setRestaurant($restaurant)
            ->setCategory($category);

        $this->entityManager->persist($product);
        $this->entityManager->flush();

        $restaurantId = $restaurant->getId();
        $productId = $product->getId();
        $categoryId = $category->getId();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'DELETE',
            '/api/admin/restaurants/'.$restaurantId,
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NO_CONTENT
        );

        $this->entityManager->clear();

        self::assertNull(
            $this->entityManager->getRepository(Restaurant::class)->find($restaurantId)
        );

        self::assertNull(
            $this->entityManager->getRepository(Product::class)->find($productId)
        );

        self::assertNull(
            $this->entityManager->getRepository(Category::class)->find($categoryId)
        );
    }

    public function testAdminCannotDeleteRestaurantWithOrders(): void
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
            'Order Client'
        );

        $restaurant = (new Restaurant())
            ->setName('Restaurant With Orders')
            ->setDescription(null)
            ->setIsAvailable(true);

        $this->entityManager->persist($restaurant);

        $deliveryZone = (new DeliveryZone())
            ->setName('Zone '.random_int(1000, 9999))
            ->setFee('4.000');

        $this->entityManager->persist($deliveryZone);

        $order = (new Order())
            ->setUser($clientUser)
            ->setRestaurant($restaurant)
            ->setDeliveryAddress('Tunis, Tunisia')
            ->setDeliveryZone($deliveryZone)
            ->setDeliveryFee('4.000')
            ->setTotalAmount('4.000')
            ->setStatus(OrderStatus::PENDING);

        $this->entityManager->persist($order);
        $this->entityManager->flush();

        $restaurantId = $restaurant->getId();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'DELETE',
            '/api/admin/restaurants/'.$restaurantId,
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_CONFLICT
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'This restaurant has existing orders and cannot be deleted. Deactivate it instead.',
            $response['message']
        );

        $this->entityManager->clear();

        self::assertNotNull(
            $this->entityManager->getRepository(Restaurant::class)->find($restaurantId)
        );
    }

    public function testNonAdminCannotDeleteRestaurant(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $restaurant = (new Restaurant())
            ->setName('Protected Restaurant')
            ->setDescription(null)
            ->setIsAvailable(true);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        $restaurantId = $restaurant->getId();

        $token = $this->authenticateClient(
            $client,
            $clientUser
        );

        $client->request(
            'DELETE',
            '/api/admin/restaurants/'.$restaurantId,
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );

        $this->entityManager->clear();

        self::assertNotNull(
            $this->entityManager->getRepository(Restaurant::class)->find($restaurantId)
        );
    }

    public function testAdminCanUploadAndReplaceAndRemoveRestaurantPhoto(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = (new Restaurant())
            ->setName('Photo Restaurant')
            ->setDescription(null)
            ->setIsAvailable(true);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        $restaurantId = $restaurant->getId();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        // Upload
        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurantId.'/photo',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            files: [
                'photo' => $this->createPngUploadedFile(),
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsString($response['photoUrl']);
        self::assertStringStartsWith('/uploads/restaurants/', $response['photoUrl']);

        $this->entityManager->clear();

        $restaurant = $this->entityManager
            ->getRepository(Restaurant::class)
            ->find($restaurantId);

        $firstFilename = $restaurant->getPhotoFilename();

        self::assertNotNull($firstFilename);

        $uploadsDir = self::getContainer()->getParameter('kernel.project_dir').'/public/uploads/restaurants';

        self::assertFileExists($uploadsDir.'/'.$firstFilename);

        // Replace
        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurantId.'/photo',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            files: [
                'photo' => $this->createPngUploadedFile(),
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $this->entityManager->clear();

        $restaurant = $this->entityManager
            ->getRepository(Restaurant::class)
            ->find($restaurantId);

        $secondFilename = $restaurant->getPhotoFilename();

        self::assertNotNull($secondFilename);
        self::assertNotSame($firstFilename, $secondFilename);
        self::assertFileDoesNotExist($uploadsDir.'/'.$firstFilename);
        self::assertFileExists($uploadsDir.'/'.$secondFilename);

        // Remove
        $client->request(
            'DELETE',
            '/api/admin/restaurants/'.$restaurantId.'/photo',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertNull($response['photoUrl']);
        self::assertFileDoesNotExist($uploadsDir.'/'.$secondFilename);
    }

    public function testUploadingNonImageRestaurantPhotoIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = (new Restaurant())
            ->setName('Text File Restaurant')
            ->setDescription(null)
            ->setIsAvailable(true);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        $restaurantId = $restaurant->getId();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurantId.'/photo',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            files: [
                'photo' => $this->createTextUploadedFile(),
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
            'Only JPEG, PNG or WebP images are allowed.',
            $response['message']
        );
    }

    public function testNonAdminCannotUploadRestaurantPhoto(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $restaurant = (new Restaurant())
            ->setName('Protected Photo Restaurant')
            ->setDescription(null)
            ->setIsAvailable(true);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        $restaurantId = $restaurant->getId();

        $token = $this->authenticateClient(
            $client,
            $clientUser
        );

        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurantId.'/photo',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            files: [
                'photo' => $this->createPngUploadedFile(),
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    private function createPngUploadedFile(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'photo').'.png';

        file_put_contents(
            $path,
            base64_decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
            )
        );

        return new UploadedFile($path, 'photo.png', 'image/png', null, true);
    }

    private function createTextUploadedFile(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'notes').'.txt';

        file_put_contents($path, 'This is not an image.');

        return new UploadedFile($path, 'notes.txt', 'text/plain', null, true);
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

        // Deleted in dependency order so leftover orders/deliveries from
        // other test classes don't trip a foreign key violation.
        $this->entityManager
            ->createQuery('DELETE FROM App\Entity\Delivery d')
            ->execute();

        $this->entityManager
            ->createQuery('DELETE FROM App\Entity\OrderItem oi')
            ->execute();

        $this->entityManager
            ->createQuery('DELETE FROM App\Entity\Order o')
            ->execute();

        $this->entityManager
            ->createQuery('DELETE FROM App\Entity\Product p')
            ->execute();

        $this->entityManager
            ->createQuery('DELETE FROM App\Entity\Category c')
             ->execute();

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
    public function testAdminCanShowRestaurant(): void
{
    $client = static::createClient();

    $this->entityManager = self::getContainer()
        ->get(EntityManagerInterface::class);

    $admin = $this->createTestUser(
        'ROLE_ADMIN',
        'Test Admin'
    );

    $restaurant = (new Restaurant())
        ->setName('Show Restaurant')
        ->setDescription('Restaurant to display')
        ->setIsAvailable(true);

    $this->entityManager->persist($restaurant);
    $this->entityManager->flush();

    $restaurantId = $restaurant->getId();

    $adminToken = $this->authenticateClient(
        $client,
        $admin
    );

    $client->request(
        'GET',
        '/api/admin/restaurants/'.$restaurantId,
        server: [
            'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
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
        $restaurantId,
        $response['id']
    );

    self::assertSame(
        'Show Restaurant',
        $response['name']
    );

    self::assertSame(
        'Restaurant to display',
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

    $adminToken = $this->authenticateClient(
        $client,
        $admin
    );

    $client->request(
        'GET',
        '/api/admin/restaurants/999999',
        server: [
            'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
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

    $restaurant = (new Restaurant())
        ->setName('Old Restaurant Name')
        ->setDescription('Old description')
        ->setIsAvailable(true);

    $this->entityManager->persist($restaurant);
    $this->entityManager->flush();

    $restaurantId = $restaurant->getId();

    $adminToken = $this->authenticateClient(
        $client,
        $admin
    );

    $client->request(
        'PUT',
        '/api/admin/restaurants/'.$restaurantId,
        server: [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
        ],
        content: json_encode([
            'name' => 'Updated Restaurant Name',
            'description' => 'Updated description',
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
        $restaurantId,
        $response['id']
    );

    self::assertSame(
        'Updated Restaurant Name',
        $response['name']
    );

    self::assertSame(
        'Updated description',
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
        'Updated Restaurant Name',
        $updatedRestaurant->getName()
    );

    self::assertSame(
        'Updated description',
        $updatedRestaurant->getDescription()
    );

    self::assertFalse(
        $updatedRestaurant->isAvailable()
    );
}

public function testAdminCannotUpdateRestaurantWithInvalidData(): void
{
    $client = static::createClient();

    $this->entityManager = self::getContainer()
        ->get(EntityManagerInterface::class);

    $admin = $this->createTestUser(
        'ROLE_ADMIN',
        'Test Admin'
    );

    $restaurant = (new Restaurant())
        ->setName('Valid Restaurant')
        ->setDescription('Valid description')
        ->setIsAvailable(true);

    $this->entityManager->persist($restaurant);
    $this->entityManager->flush();

    $restaurantId = $restaurant->getId();

    $adminToken = $this->authenticateClient(
        $client,
        $admin
    );

    $client->request(
        'PUT',
        '/api/admin/restaurants/'.$restaurantId,
        server: [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
        ],
        content: json_encode([
            'name' => '',
            'description' => 'Invalid update',
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

    self::assertArrayHasKey(
        'name',
        array_column(
            $response['errors'],
            'message',
            'field'
        )
    );
}

public function testAdminCanChangeRestaurantAvailability(): void
{
    $client = static::createClient();

    $this->entityManager = self::getContainer()
        ->get(EntityManagerInterface::class);

    $admin = $this->createTestUser(
        'ROLE_ADMIN',
        'Test Admin'
    );

    $restaurant = (new Restaurant())
        ->setName('Availability Restaurant')
        ->setDescription('Availability test')
        ->setIsAvailable(true);

    $this->entityManager->persist($restaurant);
    $this->entityManager->flush();

    $restaurantId = $restaurant->getId();

    $adminToken = $this->authenticateClient(
        $client,
        $admin
    );

    $client->request(
        'PATCH',
        '/api/admin/restaurants/'.$restaurantId.'/availability',
        server: [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
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

    self::assertSame(
        $restaurantId,
        $response['id']
    );

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

public function testAdminCannotChangeAvailabilityWithInvalidData(): void
{
    $client = static::createClient();

    $this->entityManager = self::getContainer()
        ->get(EntityManagerInterface::class);

    $admin = $this->createTestUser(
        'ROLE_ADMIN',
        'Test Admin'
    );

    $restaurant = (new Restaurant())
        ->setName('Invalid Availability Restaurant')
        ->setDescription('Availability validation test')
        ->setIsAvailable(true);

    $this->entityManager->persist($restaurant);
    $this->entityManager->flush();

    $restaurantId = $restaurant->getId();

    $adminToken = $this->authenticateClient(
        $client,
        $admin
    );

    $client->request(
        'PATCH',
        '/api/admin/restaurants/'.$restaurantId.'/availability',
        server: [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
        ],
        content: json_encode([])
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
}
