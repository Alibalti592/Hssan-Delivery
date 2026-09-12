<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\OrderItem;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\OrderStatus;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\File\UploadedFile;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class AdminProductApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    protected function tearDown(): void
    {
        if (isset($this->entityManager)) {
            $this->entityManager
                ->createQuery('DELETE FROM App\Entity\Product p')
                ->execute();

            $this->entityManager->clear();
        }

        parent::tearDown();
    }

    public function testAdminCanCreateProduct(): void
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
            'Burgers'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurant->getId().'/products',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Cheeseburger',
                'description' => 'Beef burger with cheese',
                'price' => '18.500',
                'categoryId' => $category->getId(),
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
            'Cheeseburger',
            $response['name']
        );
        self::assertSame(
            'Beef burger with cheese',
            $response['description']
        );
        self::assertSame(
            '18.500',
            $response['price']
        );
        self::assertTrue(
            $response['isAvailable']
        );
        self::assertSame(
            $restaurant->getId(),
            $response['restaurantId']
        );
        self::assertSame(
            $category->getId(),
            $response['categoryId']
        );

        $this->entityManager->clear();

        $product = $this->entityManager
            ->getRepository(Product::class)
            ->find($response['id']);

        self::assertNotNull($product);

        self::assertSame(
            'Cheeseburger',
            $product->getName()
        );

        self::assertSame(
            'Beef burger with cheese',
            $product->getDescription()
        );

        self::assertSame(
            '18.500',
            $product->getPrice()
        );

        self::assertTrue(
            $product->isAvailable()
        );

        self::assertSame(
            $restaurant->getId(),
            $product->getRestaurant()?->getId()
        );

        self::assertSame(
            $category->getId(),
            $product->getCategory()?->getId()
        );
    }

    public function testNonAdminCannotCreateProduct(): void
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
            'Burgers'
        );

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurant->getId().'/products',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Unauthorized Product',
                'description' => 'Should not be created',
                'price' => '10.000',
                'categoryId' => $category->getId(),
                'isAvailable' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testInvalidProductDataIsRejected(): void
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
            'Burgers'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurant->getId().'/products',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => '',
                'description' => 'Invalid product',
                'price' => 'invalid',
                'categoryId' => $category->getId(),
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

    public function testCreatingProductWithUnknownRestaurantReturns404(): void
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
            '/api/admin/restaurants/999999/products',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Burger',
                'description' => 'Burger',
                'price' => '15.000',
                'categoryId' => 1,
                'isAvailable' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testCreatingProductWithUnknownCategoryReturns400(): void
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
            '/api/admin/restaurants/'.$restaurant->getId().'/products',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Burger',
                'description' => 'Burger',
                'price' => '15.000',
                'categoryId' => 999999,
                'isAvailable' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_BAD_REQUEST
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);

        self::assertSame(
            'Category not found.',
            $response['message']
        );
    }

    public function testCreatingProductWithCategoryFromAnotherRestaurantReturns400(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant(
            'Restaurant One'
        );

        $otherRestaurant = $this->createRestaurant(
            'Restaurant Two'
        );

        $otherCategory = $this->createCategory(
            $otherRestaurant,
            'Other Category'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/restaurants/'.$restaurant->getId().'/products',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Burger',
                'description' => 'Burger',
                'price' => '15.000',
                'categoryId' => $otherCategory->getId(),
                'isAvailable' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_BAD_REQUEST
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);

        self::assertSame(
            'Category does not belong to this restaurant.',
            $response['message']
        );
    }

    public function testAdminCanListProductsForRestaurant(): void
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
            'Burgers'
        );

        $this->createProduct(
            $restaurant,
            $category,
            'Burger',
            '15.000'
        );

        $this->createProduct(
            $restaurant,
            $category,
            'Cheeseburger',
            '18.500'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/restaurants/'.$restaurant->getId().'/products',
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
            $response['items']
        );

        self::assertSame(
            'Burger',
            $response['items'][0]['name']
        );

        self::assertSame(
            'Cheeseburger',
            $response['items'][1]['name']
        );

        self::assertSame(
            '15.000',
            $response['items'][0]['price']
        );

        self::assertSame(
            '18.500',
            $response['items'][1]['price']
        );
    }

    public function testAdminGetsEmptyProductList(): void
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
            '/api/admin/restaurants/'.$restaurant->getId().'/products',
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
            $response['items']
        );
        self::assertSame(0, $response['meta']['total']);
    }

    public function testAdminGets404ForUnknownProductRestaurant(): void
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
            '/api/admin/restaurants/999999/products',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testAdminCanShowProduct(): void
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

        $product = $this->createProduct(
            $restaurant,
            $category,
            'Tiramisu',
            '12.500'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/products/'.$product->getId(),
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
            $product->getId(),
            $response['id']
        );

        self::assertSame(
            'Tiramisu',
            $response['name']
        );

        self::assertSame(
            '12.500',
            $response['price']
        );

        self::assertSame(
            $restaurant->getId(),
            $response['restaurantId']
        );

        self::assertSame(
            $category->getId(),
            $response['categoryId']
        );
    }

    public function testAdminGets404ForUnknownProduct(): void
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
            '/api/admin/products/999999',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testAdminCanUpdateProduct(): void
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
            'Burgers'
        );

        $product = $this->createProduct(
            $restaurant,
            $category,
            'Old Burger',
            '15.000'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PUT',
            '/api/admin/products/'.$product->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'New Burger',
                'description' => 'Updated burger',
                'price' => '19.500',
                'categoryId' => $category->getId(),
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
            'New Burger',
            $response['name']
        );

        self::assertSame(
            'Updated burger',
            $response['description']
        );

        self::assertSame(
            '19.500',
            $response['price']
        );

        self::assertFalse(
            $response['isAvailable']
        );

        $this->entityManager->clear();

        $updatedProduct = $this->entityManager
            ->getRepository(Product::class)
            ->find($product->getId());

        self::assertNotNull($updatedProduct);

        self::assertSame(
            'New Burger',
            $updatedProduct->getName()
        );

        self::assertSame(
            'Updated burger',
            $updatedProduct->getDescription()
        );

        self::assertSame(
            '19.500',
            $updatedProduct->getPrice()
        );

        self::assertFalse(
            $updatedProduct->isAvailable()
        );

        self::assertSame(
            $restaurant->getId(),
            $updatedProduct->getRestaurant()?->getId()
        );

        self::assertSame(
            $category->getId(),
            $updatedProduct->getCategory()?->getId()
        );
    }

    public function testInvalidProductUpdateIsRejected(): void
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
            'Burgers'
        );

        $product = $this->createProduct(
            $restaurant,
            $category,
            'Valid Burger',
            '15.000'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PUT',
            '/api/admin/products/'.$product->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => '',
                'description' => 'Invalid product',
                'price' => 'invalid',
                'categoryId' => $category->getId(),
                'isAvailable' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNPROCESSABLE_ENTITY
        );
    }

    public function testNonAdminCannotUpdateProduct(): void
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
            'Burgers'
        );

        $product = $this->createProduct(
            $restaurant,
            $category,
            'Protected Burger',
            '15.000'
        );

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'PUT',
            '/api/admin/products/'.$product->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Hacked Burger',
                'description' => 'Should not update',
                'price' => '1.000',
                'categoryId' => $category->getId(),
                'isAvailable' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testAdminCanChangeProductAvailability(): void
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
            'Burgers'
        );

        $product = $this->createProduct(
            $restaurant,
            $category,
            'Burger',
            '15.000',
            true
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PATCH',
            '/api/admin/products/'.$product->getId().'/availability',
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

        $updatedProduct = $this->entityManager
            ->getRepository(Product::class)
            ->find($product->getId());

        self::assertNotNull($updatedProduct);

        self::assertFalse(
            $updatedProduct->isAvailable()
        );
    }

    public function testInvalidProductAvailabilityIsRejected(): void
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
            'Burgers'
        );

        $product = $this->createProduct(
            $restaurant,
            $category,
            'Burger',
            '15.000'
        );

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PATCH',
            '/api/admin/products/'.$product->getId().'/availability',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'isAvailable' => 'false',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNPROCESSABLE_ENTITY
        );
    }

    public function testAdminCanDeleteProductWithoutOrders(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant('Test Restaurant');
        $category = $this->createCategory($restaurant, 'Burgers');
        $product = $this->createProduct($restaurant, $category, 'Burger', '15.000');

        $productId = $product->getId();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'DELETE',
            '/api/admin/products/'.$productId,
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NO_CONTENT
        );

        $this->entityManager->clear();

        self::assertNull(
            $this->entityManager->getRepository(Product::class)->find($productId)
        );
    }

    public function testAdminCannotDeleteProductWithOrders(): void
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

        $restaurant = $this->createRestaurant('Test Restaurant');
        $category = $this->createCategory($restaurant, 'Burgers');
        $product = $this->createProduct($restaurant, $category, 'Burger', '15.000');

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
            ->setTotalAmount('19.000')
            ->setStatus(OrderStatus::PENDING);

        $this->entityManager->persist($order);

        $orderItem = (new OrderItem())
            ->setOrder($order)
            ->setProduct($product)
            ->setQuantity(1)
            ->setUnitPrice('15.000');

        $this->entityManager->persist($orderItem);
        $this->entityManager->flush();

        $productId = $product->getId();
        $orderItemId = $orderItem->getId();
        $orderId = $order->getId();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'DELETE',
            '/api/admin/products/'.$productId,
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
            'This product has existing orders and cannot be deleted. Deactivate it instead.',
            $response['message']
        );

        // Release the FK before this file's tearDown() bulk-deletes products.
        // The requests above rebooted the kernel, detaching every entity
        // already fetched through $this->entityManager, so clear() and
        // re-fetch by id before removing.
        $this->entityManager->clear();

        $this->entityManager->remove(
            $this->entityManager->getRepository(OrderItem::class)->find($orderItemId)
        );
        $this->entityManager->remove(
            $this->entityManager->getRepository(Order::class)->find($orderId)
        );
        $this->entityManager->flush();
    }

    public function testNonAdminCannotDeleteProduct(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $restaurant = $this->createRestaurant('Test Restaurant');
        $category = $this->createCategory($restaurant, 'Burgers');
        $product = $this->createProduct($restaurant, $category, 'Burger', '15.000');

        $token = $this->authenticateClient(
            $client,
            $clientUser
        );

        $client->request(
            'DELETE',
            '/api/admin/products/'.$product->getId(),
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testAdminCanUploadAndReplaceAndRemoveProductPhoto(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant('Test Restaurant');
        $category = $this->createCategory($restaurant, 'Burgers');
        $product = $this->createProduct($restaurant, $category, 'Burger', '15.000');

        $productId = $product->getId();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        // Upload
        $client->request(
            'POST',
            '/api/admin/products/'.$productId.'/photo',
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
        self::assertStringStartsWith('/uploads/products/', $response['photoUrl']);

        $this->entityManager->clear();

        $product = $this->entityManager
            ->getRepository(Product::class)
            ->find($productId);

        $firstFilename = $product->getPhotoFilename();

        self::assertNotNull($firstFilename);

        $uploadsDir = self::getContainer()->getParameter('kernel.project_dir').'/public/uploads/products';

        self::assertFileExists($uploadsDir.'/'.$firstFilename);

        // Replace
        $client->request(
            'POST',
            '/api/admin/products/'.$productId.'/photo',
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

        $product = $this->entityManager
            ->getRepository(Product::class)
            ->find($productId);

        $secondFilename = $product->getPhotoFilename();

        self::assertNotNull($secondFilename);
        self::assertNotSame($firstFilename, $secondFilename);
        self::assertFileDoesNotExist($uploadsDir.'/'.$firstFilename);
        self::assertFileExists($uploadsDir.'/'.$secondFilename);

        // Remove
        $client->request(
            'DELETE',
            '/api/admin/products/'.$productId.'/photo',
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

    public function testUploadingNonImageProductPhotoIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $restaurant = $this->createRestaurant('Test Restaurant');
        $category = $this->createCategory($restaurant, 'Burgers');
        $product = $this->createProduct($restaurant, $category, 'Burger', '15.000');

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/products/'.$product->getId().'/photo',
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

    public function testNonAdminCannotUploadProductPhoto(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $restaurant = $this->createRestaurant('Test Restaurant');
        $category = $this->createCategory($restaurant, 'Burgers');
        $product = $this->createProduct($restaurant, $category, 'Burger', '15.000');

        $token = $this->authenticateClient(
            $client,
            $clientUser
        );

        $client->request(
            'POST',
            '/api/admin/products/'.$product->getId().'/photo',
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

    private function createProduct(
        Restaurant $restaurant,
        Category $category,
        string $name,
        string $price,
        bool $isAvailable = true,
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