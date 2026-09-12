<?php

namespace App\Tests\Integration;

use App\Entity\DeviceToken;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class DeviceTokenApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    public function testAuthenticatedUserCanRegisterADeviceToken(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_CLIENT', 'Test Client');
        $token = $this->authenticateClient($client, $user);
        $deviceToken = $this->uniqueToken();

        $client->request(
            'POST',
            '/api/notifications/device-token',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'token' => $deviceToken,
                'platform' => 'android',
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $this->entityManager->clear();

        $stored = $this->entityManager
            ->getRepository(DeviceToken::class)
            ->findOneBy(['token' => $deviceToken]);

        self::assertNotNull($stored);
        self::assertSame($user->getId(), $stored->getUser()->getId());
        self::assertSame('android', $stored->getPlatform());
    }

    public function testRegisteringAnExistingTokenReassignsItToTheNewUser(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $firstUser = $this->createTestUser('ROLE_CLIENT', 'First Owner');
        $secondUser = $this->createTestUser('ROLE_CLIENT', 'Second Owner');
        $deviceToken = $this->uniqueToken();

        $firstToken = $this->authenticateClient($client, $firstUser);

        $client->request(
            'POST',
            '/api/notifications/device-token',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$firstToken,
            ],
            content: json_encode(['token' => $deviceToken])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        // Same device, different account signed in — e.g. the first user
        // signed out and a second user signed in on the same phone.
        $secondToken = $this->authenticateClient($client, $secondUser);

        $client->request(
            'POST',
            '/api/notifications/device-token',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$secondToken,
            ],
            content: json_encode(['token' => $deviceToken])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $this->entityManager->clear();

        $matches = $this->entityManager
            ->getRepository(DeviceToken::class)
            ->findBy(['token' => $deviceToken]);

        self::assertCount(1, $matches, 'The token must not be duplicated across users.');
        self::assertSame($secondUser->getId(), $matches[0]->getUser()->getId());
    }

    public function testBlankTokenIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_CLIENT', 'Test Client');
        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/notifications/device-token',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode(['token' => ''])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    public function testUnauthenticatedRequestIsRejected(): void
    {
        $client = static::createClient();

        $client->request(
            'POST',
            '/api/notifications/device-token',
            server: ['CONTENT_TYPE' => 'application/json'],
            content: json_encode(['token' => $this->uniqueToken()])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    public function testAuthenticatedUserCanUnregisterADeviceToken(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_CLIENT', 'Test Client');
        $token = $this->authenticateClient($client, $user);
        $deviceToken = $this->uniqueToken();

        $client->request(
            'POST',
            '/api/notifications/device-token',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode(['token' => $deviceToken])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $client->request(
            'DELETE',
            '/api/notifications/device-token',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode(['token' => $deviceToken])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $this->entityManager->clear();

        $stored = $this->entityManager
            ->getRepository(DeviceToken::class)
            ->findOneBy(['token' => $deviceToken]);

        self::assertNull($stored);
    }

    public function testUnregisteringAnUnknownTokenIsANoop(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_CLIENT', 'Test Client');
        $token = $this->authenticateClient($client, $user);

        $client->request(
            'DELETE',
            '/api/notifications/device-token',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode(['token' => $this->uniqueToken()])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);
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

    private function uniqueToken(): string
    {
        return 'fcm-token-'.bin2hex(random_bytes(16));
    }
}
