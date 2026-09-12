<?php

namespace App\Tests\Integration;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

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
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
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
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
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
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
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
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
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
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
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

    public function testAdminCanListCouriers(): void
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
            'List Courier'
        );

        $client_ = $this->createTestUser(
            'ROLE_USER',
            'Not A Courier'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/couriers',
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

        $ids = array_column($response['items'], 'id');

        self::assertContains($courier->getId(), $ids);
        self::assertNotContains($client_->getId(), $ids);
        self::assertSame(1, $response['meta']['page']);
    }

    public function testAdminCanPaginateCouriers(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        // Not a courier — must never be counted or returned, regardless of
        // page/limit, since the courier filter runs as a separate raw-SQL
        // pass before pagination.
        $this->createTestUser('ROLE_USER', 'Plain Client');

        $adminToken = $this->authenticateClient($client, $admin);

        // The suite shares one Postgres database across tests (no per-test
        // transaction/rollback — see AuthApiTest for the same caveat with
        // the rate limiter), so other tests' couriers may already exist.
        // Take a baseline count instead of assuming a clean slate.
        $client->request(
            'GET',
            '/api/admin/couriers?page=1&limit=1',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $baselineTotal = json_decode($client->getResponse()->getContent(), true)['meta']['total'];

        $couriers = [];
        for ($i = 0; $i < 3; ++$i) {
            $couriers[] = $this->createTestUser('ROLE_LIVREUR', "Paginate Courier $i");
        }

        $expectedTotal = $baselineTotal + 3;
        $lastPage = (int) ceil($expectedTotal / 2);

        $client->request(
            'GET',
            '/api/admin/couriers?page=1&limit=2',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken]
        );

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertCount(2, $response['items']);
        self::assertSame([
            'page' => 1,
            'limit' => 2,
            'total' => $expectedTotal,
            'pages' => $lastPage,
        ], $response['meta']);

        // Walk every page and confirm each of the 3 new couriers appears
        // exactly once across the whole listing, with no duplicates.
        $seenIds = [];
        for ($page = 1; $page <= $lastPage; ++$page) {
            $client->request(
                'GET',
                "/api/admin/couriers?page=$page&limit=2",
                server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken]
            );
            $pageData = json_decode($client->getResponse()->getContent(), true);
            foreach ($pageData['items'] as $item) {
                $seenIds[] = $item['id'];
            }
        }

        self::assertSame(
            count($seenIds),
            count(array_unique($seenIds)),
            'No courier should appear on more than one page.'
        );

        foreach ($couriers as $courier) {
            self::assertContains($courier->getId(), $seenIds);
        }
    }

    public function testNonAdminCannotListCouriers(): void
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
            '/api/admin/couriers',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testAdminCanShowCourier(): void
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
            'Show Courier'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/couriers/'.$courier->getId(),
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

        self::assertSame($courier->getId(), $response['id']);
        self::assertSame('Show Courier', $response['name']);
        self::assertTrue($response['isActive']);
    }

    public function testAdminGets404ForUnknownCourier(): void
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
            '/api/admin/couriers/999999',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testAdminGets404WhenShowingNonCourierUserAsCourier(): void
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
            'Not A Courier'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/couriers/'.$clientUser->getId(),
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testAdminCanDeactivateAndReactivateCourier(): void
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
            'Toggle Courier'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PATCH',
            '/api/admin/couriers/'.$courier->getId().'/active',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'isActive' => false,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertFalse($response['isActive']);

        $this->entityManager->clear();

        $deactivated = $this->entityManager
            ->getRepository(User::class)
            ->find($courier->getId());

        self::assertFalse($deactivated->isActive());

        $client->request(
            'PATCH',
            '/api/admin/couriers/'.$courier->getId().'/active',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'isActive' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertTrue($response['isActive']);
    }

    public function testNonAdminCannotDeactivateCourier(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Protected Courier'
        );

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'PATCH',
            '/api/admin/couriers/'.$courier->getId().'/active',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'isActive' => false,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testDeactivatedCourierCannotLogin(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Locked Out Courier'
        );

        $courier->setActive(false);

        $this->entityManager->flush();

        $client->request(
            'POST',
            '/api/auth/login',
            server: [
                'CONTENT_TYPE' => 'application/json',
            ],
            content: json_encode([
                'phone' => $courier->getPhone(),
                'password' => 'password123',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNAUTHORIZED
        );
    }

    public function testAdminCanResetCourierPassword(): void
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
            'Locked Courier'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PATCH',
            '/api/admin/couriers/'.$courier->getId().'/password',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'password' => 'newPassword456',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $client->request(
            'POST',
            '/api/auth/login',
            server: [
                'CONTENT_TYPE' => 'application/json',
            ],
            content: json_encode([
                'phone' => $courier->getPhone(),
                'password' => 'newPassword456',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $client->request(
            'POST',
            '/api/auth/login',
            server: [
                'CONTENT_TYPE' => 'application/json',
            ],
            content: json_encode([
                'phone' => $courier->getPhone(),
                'password' => 'password123',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNAUTHORIZED
        );
    }

    public function testNonAdminCannotResetCourierPassword(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $courier = $this->createTestUser(
            'ROLE_LIVREUR',
            'Protected Courier'
        );

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'PATCH',
            '/api/admin/couriers/'.$courier->getId().'/password',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'password' => 'newPassword456',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testAdminGets404WhenResettingUnknownCourierPassword(): void
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
            'PATCH',
            '/api/admin/couriers/999999/password',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'password' => 'newPassword456',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testCourierPasswordResetRejectsShortPassword(): void
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
            'Short Password Courier'
        );

        $adminToken = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PATCH',
            '/api/admin/couriers/'.$courier->getId().'/password',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'password' => '123',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNPROCESSABLE_ENTITY
        );
    }

    private function createTestUser(
        string $role,
        string $name,
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
        string $phone,
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
}
