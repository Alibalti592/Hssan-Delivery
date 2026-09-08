<?php

namespace App\Tests\Integration;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;

final class AuthApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function testClientCanRegister(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $phone = $this->uniquePhone();

        $client->request(
            'POST',
            '/api/auth/register',
            server: [
                'CONTENT_TYPE' => 'application/json',
            ],
            content: json_encode([
                'name' => 'Test Client',
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
            'Test Client',
            $response['name']
        );

        self::assertSame(
            $phone,
            $response['phone']
        );

        self::assertContains(
            'ROLE_CLIENT',
            $response['roles']
        );

        self::assertTrue(
            $response['isVerified']
        );

        self::assertArrayNotHasKey(
            'password',
            $response
        );

        $user = $this->entityManager
            ->getRepository(User::class)
            ->findOneBy([
                'phone' => $phone,
            ]);

        self::assertNotNull($user);

        self::assertSame(
            'Test Client',
            $user->getName()
        );

        self::assertContains(
            'ROLE_CLIENT',
            $user->getRoles()
        );

        self::assertTrue(
            $user->isVerified()
        );

        self::assertNotSame(
            'password123',
            $user->getPassword()
        );
    }

    public function testClientCanLogin(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

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

        self::assertNotEmpty(
            $response['token']
        );

        self::assertIsString(
            $response['token']
        );
    }

    public function testAuthenticatedUserCanAccessMe(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'GET',
            '/api/auth/me',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
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
            $user->getId(),
            $response['id']
        );

        self::assertSame(
            $user->getName(),
            $response['name']
        );

        self::assertSame(
            $user->getPhone(),
            $response['phone']
        );

        self::assertContains(
            'ROLE_CLIENT',
            $response['roles']
        );

        self::assertTrue(
            $response['isVerified']
        );

        self::assertArrayNotHasKey(
            'password',
            $response
        );
    }

    public function testDuplicatePhoneIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $phone = $this->uniquePhone();

        $client->request(
            'POST',
            '/api/auth/register',
            server: [
                'CONTENT_TYPE' => 'application/json',
            ],
            content: json_encode([
                'name' => 'First User',
                'phone' => $phone,
                'password' => 'password123',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_CREATED
        );

        $client->request(
            'POST',
            '/api/auth/register',
            server: [
                'CONTENT_TYPE' => 'application/json',
            ],
            content: json_encode([
                'name' => 'Second User',
                'phone' => $phone,
                'password' => 'password456',
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
            $response['error']
        );
    }

    public function testLoginFailsWithWrongPassword(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser();

        $client->request(
            'POST',
            '/api/auth/login',
            server: [
                'CONTENT_TYPE' => 'application/json',
            ],
            content: json_encode([
                'phone' => $user->getPhone(),
                'password' => 'wrong-password',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNAUTHORIZED
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertIsArray($response);

        self::assertArrayHasKey(
            'code',
            $response
        );

        self::assertSame(
            Response::HTTP_UNAUTHORIZED,
            $response['code']
        );
    }

    public function testInvalidRegistrationDataIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $client->request(
            'POST',
            '/api/auth/register',
            server: [
                'CONTENT_TYPE' => 'application/json',
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

        self::assertArrayHasKey(
            'message',
            $response
        );

        self::assertSame(
            'Validation failed.',
            $response['message']
        );

        self::assertArrayHasKey(
            'errors',
            $response
        );

        self::assertNotEmpty(
            $response['errors']
        );
    }

    public function testUnauthenticatedUserCannotAccessMe(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $client->request(
            'GET',
            '/api/auth/me'
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNAUTHORIZED
        );
    }

    private function createTestUser(): User
    {
        $phone = $this->uniquePhone();

        $user = new User();

        $user->setName('Test Client');
        $user->setPhone($phone);
        $user->setRoles(['ROLE_CLIENT']);
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
        return '2' . random_int(
            10000000,
            99999999
        );
    }
}