<?php

namespace App\Tests\Integration;

use App\Entity\DeliveryZone;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class AdminDeliveryZoneApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    public function testAdminCanCreateDeliveryZone(): void
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
            '/api/admin/delivery-zones',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Test Zone Alpha',
                'fee' => '4.000',
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
        self::assertSame('Test Zone Alpha', $response['name']);
        self::assertSame('4.000', $response['fee']);

        $this->entityManager->clear();

        $zone = $this->entityManager
            ->getRepository(DeliveryZone::class)
            ->find($response['id']);

        self::assertNotNull($zone);
        self::assertSame('Test Zone Alpha', $zone->getName());
        self::assertSame('4.000', $zone->getFee());
    }

    public function testNonAdminCannotCreateDeliveryZone(): void
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
            '/api/admin/delivery-zones',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Unauthorized Zone',
                'fee' => '4.000',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    public function testInvalidDeliveryZoneDataIsRejected(): void
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
            '/api/admin/delivery-zones',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => '',
                'fee' => 'not-a-decimal',
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

    public function testCreatingDeliveryZoneWithDuplicateNameReturns409(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $this->createDeliveryZone('Duplicate Zone', '5.000');

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'POST',
            '/api/admin/delivery-zones',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Duplicate Zone',
                'fee' => '6.000',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_CONFLICT
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame(
            'A delivery zone with this name already exists.',
            $response['message']
        );
    }

    public function testAdminCanListDeliveryZones(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $this->createDeliveryZone('List Zone A', '4.000');
        $this->createDeliveryZone('List Zone B', '7.000');

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/delivery-zones',
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

        $names = array_column($response, 'name');

        self::assertContains('List Zone A', $names);
        self::assertContains('List Zone B', $names);
    }

    public function testAdminCanShowDeliveryZone(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $zone = $this->createDeliveryZone('Show Zone', '5.000');

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'GET',
            '/api/admin/delivery-zones/'.$zone->getId(),
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

        self::assertSame($zone->getId(), $response['id']);
        self::assertSame('Show Zone', $response['name']);
        self::assertSame('5.000', $response['fee']);
    }

    public function testAdminGets404ForUnknownDeliveryZone(): void
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
            '/api/admin/delivery-zones/999999',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testAdminCanUpdateDeliveryZone(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $zone = $this->createDeliveryZone('Old Zone Name', '4.000');

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PUT',
            '/api/admin/delivery-zones/'.$zone->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'New Zone Name',
                'fee' => '8.000',
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

        self::assertSame('New Zone Name', $response['name']);
        self::assertSame('8.000', $response['fee']);

        $this->entityManager->clear();

        $updatedZone = $this->entityManager
            ->getRepository(DeliveryZone::class)
            ->find($zone->getId());

        self::assertNotNull($updatedZone);
        self::assertSame('New Zone Name', $updatedZone->getName());
        self::assertSame('8.000', $updatedZone->getFee());
    }

    public function testInvalidDeliveryZoneUpdateIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $zone = $this->createDeliveryZone('Valid Zone Name', '4.000');

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PUT',
            '/api/admin/delivery-zones/'.$zone->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => '',
                'fee' => '4.000',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNPROCESSABLE_ENTITY
        );
    }

    public function testUpdatingDeliveryZoneToDuplicateNameReturns409(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser(
            'ROLE_ADMIN',
            'Test Admin'
        );

        $this->createDeliveryZone('Taken Zone Name', '4.000');
        $zone = $this->createDeliveryZone('Other Zone Name', '5.000');

        $token = $this->authenticateClient(
            $client,
            $admin
        );

        $client->request(
            'PUT',
            '/api/admin/delivery-zones/'.$zone->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Taken Zone Name',
                'fee' => '5.000',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_CONFLICT
        );
    }

    public function testNonAdminCannotUpdateDeliveryZone(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser(
            'ROLE_USER',
            'Test Client'
        );

        $zone = $this->createDeliveryZone('Protected Zone', '4.000');

        $token = $this->authenticateClient(
            $client,
            $user
        );

        $client->request(
            'PUT',
            '/api/admin/delivery-zones/'.$zone->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'name' => 'Hacked Zone',
                'fee' => '4.000',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_FORBIDDEN
        );
    }

    private function createDeliveryZone(
        string $name,
        string $fee,
    ): DeliveryZone {
        $zone = (new DeliveryZone())
            ->setName($name)
            ->setFee($fee);

        $this->entityManager->persist($zone);
        $this->entityManager->flush();

        return $zone;
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
        return '4'.random_int(
            10000000,
            99999999
        );
    }
}
