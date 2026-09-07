<?php

namespace App\Tests\Integration;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;

final class AdminCourierApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function testAdminCanCreateCourier(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $phone = $this->uniquePhone();

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/couriers',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ],
            content: json_encode([
                'name' => 'Ahmed Courier',
                'phone' => $phone,
                'password' => 'password123',
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
            'Ahmed Courier',
            $response['name']
        );

        self::assertSame(
            $phone,
            $response['phone']
        );

        self::assertContains(
            'ROLE_LIVREUR',
            $response['roles']
        );

        self::assertTrue(
            $response['verified']
        );

        self::assertArrayNotHasKey(
            'password',
            $response
        );

        $this->entityManager->clear();

        $courier = $this->entityManager
            ->getRepository(User::class)
            ->find($response['id']);

        self::assertNotNull($courier);

        self::assertSame(
            'Ahmed Courier',
            $courier->getName()
        );

        self::assertSame(
            $phone,
            $courier->getPhone()
        );

        self::assertContains(
            'ROLE_LIVREUR',
            $courier->getRoles()
        );

        self::assertTrue(
            $courier->isVerified()
        );

        self::assertNotSame(
            'password123',
            $courier->getPassword()
        );
    }

    public function testNonAdminCannotCreateCourier(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $clientUser = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $phone = $this->uniquePhone();

        $token = $this->authenticateClient(
            $client,
            $clientUser
        );

        $client->request(
            'POST',
            '/api/admin/couriers',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
            ],
            content: json_encode([
                'name' => 'Unauthorized Courier',
                'phone' => $phone,
                'password' => 'password123',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );

        $courier = $this->entityManager
            ->getRepository(User::class)
            ->findOneBy([
                'phone' => $phone,
            ]);

        self::assertNull($courier);
    }

    public function testDuplicatePhoneCannotCreateCourier(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $phone = $this->uniquePhone();

        $this->createTestUserWithPhone(
            'ROLE_USER',
            'Existing User',
            $phone
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/couriers',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ],
            content: json_encode([
                'name' => 'Duplicate Courier',
                'phone' => $phone,
                'password' => 'password123',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_CONFLICT
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);

        self::assertSame(
            'An account with this phone number already exists.',
            $response['message']
        );
    }

    public function testCreatedCourierCanLogin(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $phone = $this->uniquePhone();
        $password = 'courierPassword123';

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/couriers',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ],
            content: json_encode([
                'name' => 'Login Courier',
                'phone' => $phone,
                'password' => $password,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_CREATED
        );

        $client->request(
            'POST',
            '/api/auth/login',
            server: [
                'CONTENT_TYPE' => 'application/json',
            ],
            content: json_encode([
                'phone' => $phone,
                'password' => $password,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $loginResponse = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($loginResponse);

        self::assertArrayHasKey(
            'token',
            $loginResponse
        );

        self::assertNotEmpty(
            $loginResponse['token']
        );

        self::assertIsString(
            $loginResponse['token']
        );
    }

    public function testInvalidCourierDataIsRejected(): void
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
            '/api/admin/couriers',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer ' . $adminToken,
            ],
            content: json_encode([
                'name' => '',
                'phone' => '',
                'password' => '123',
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
        string $name
    ): User {
        return $this->createTestUserWithPhone(
            $role,
            $name,
            $this->uniquePhone()
        );
    }

    private function createTestUserWithPhone(
        string $role,
        string $name,
        string $phone
    ): User {
        $user = new User();

        $user->setName($name);
        $user->setPhone($phone);
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
        return '2' . random_int(
            10000000,
            99999999
        );
    }
}