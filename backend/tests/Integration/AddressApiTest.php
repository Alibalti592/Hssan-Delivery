<?php

namespace App\Tests\Integration;

use App\Entity\Address;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class AddressApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    public function testUserCanCreateAddress(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/addresses',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'label' => 'Domicile',
                'addressLine' => 'Rue de Carthage, Tunis',
                'instructions' => '3ème étage, porte bleue',
                'isDefault' => true,
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
        self::assertSame('Domicile', $response['label']);
        self::assertSame('Rue de Carthage, Tunis', $response['addressLine']);
        self::assertSame('3ème étage, porte bleue', $response['instructions']);
        self::assertTrue($response['isDefault']);

        $this->entityManager->clear();

        $address = $this->entityManager
            ->getRepository(Address::class)
            ->find($response['id']);

        self::assertNotNull($address);
        self::assertSame($user->getId(), $address->getUser()->getId());
    }

    public function testInvalidAddressDataIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/addresses',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'label' => '',
                'addressLine' => '',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNPROCESSABLE_ENTITY
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame('Validation failed.', $response['message']);
        self::assertArrayHasKey('errors', $response);
    }

    public function testUnauthenticatedCannotCreateAddress(): void
    {
        $client = static::createClient();

        $client->request(
            'POST',
            '/api/addresses',
            server: [
                'CONTENT_TYPE' => 'application/json',
            ],
            content: json_encode([
                'label' => 'Domicile',
                'addressLine' => 'Rue de Carthage, Tunis',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_UNAUTHORIZED
        );
    }

    public function testUserCanListOwnAddressesOnly(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client One');
        $otherUser = $this->createTestUser('Test Client Two');

        $mine = $this->createAddress($user, 'Domicile', 'Rue de Carthage, Tunis');
        $this->createAddress($otherUser, 'Bureau', 'Avenue Habib Bourguiba, Tunis');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/addresses',
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
        self::assertCount(1, $response);
        self::assertSame($mine->getId(), $response[0]['id']);
    }

    public function testUserCanShowOwnAddress(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client');

        $address = $this->createAddress($user, 'Domicile', 'Rue de Carthage, Tunis');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/addresses/'.$address->getId(),
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

        self::assertSame($address->getId(), $response['id']);
        self::assertSame('Domicile', $response['label']);
    }

    public function testUserCannotShowAnotherUsersAddress(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client');
        $otherUser = $this->createTestUser('Other Client');

        $address = $this->createAddress($otherUser, 'Bureau', 'Avenue Habib Bourguiba, Tunis');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/addresses/'.$address->getId(),
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testUserGets404ForUnknownAddress(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/addresses/999999',
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testUserCanUpdateOwnAddress(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client');

        $address = $this->createAddress($user, 'Old Label', 'Old address line');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'PUT',
            '/api/addresses/'.$address->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'label' => 'New Label',
                'addressLine' => 'New address line',
                'instructions' => 'Ring twice',
                'isDefault' => false,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $response = json_decode(
            $client->getResponse()->getContent(),
            true
        );

        self::assertSame('New Label', $response['label']);
        self::assertSame('New address line', $response['addressLine']);
        self::assertSame('Ring twice', $response['instructions']);
    }

    public function testUserCannotUpdateAnotherUsersAddress(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client');
        $otherUser = $this->createTestUser('Other Client');

        $address = $this->createAddress($otherUser, 'Bureau', 'Avenue Habib Bourguiba, Tunis');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'PUT',
            '/api/addresses/'.$address->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'label' => 'Hacked',
                'addressLine' => 'Hacked address',
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );
    }

    public function testSettingAddressAsDefaultUnsetsPreviousDefault(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client');

        $first = $this->createAddress($user, 'Domicile', 'Rue de Carthage, Tunis', true);
        $second = $this->createAddress($user, 'Bureau', 'Avenue Habib Bourguiba, Tunis', false);

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'PUT',
            '/api/addresses/'.$second->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'label' => 'Bureau',
                'addressLine' => 'Avenue Habib Bourguiba, Tunis',
                'isDefault' => true,
            ])
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_OK
        );

        $this->entityManager->clear();

        $firstReloaded = $this->entityManager
            ->getRepository(Address::class)
            ->find($first->getId());

        $secondReloaded = $this->entityManager
            ->getRepository(Address::class)
            ->find($second->getId());

        self::assertFalse($firstReloaded->isDefault());
        self::assertTrue($secondReloaded->isDefault());
    }

    public function testUserCanDeleteOwnAddress(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client');

        $address = $this->createAddress($user, 'Domicile', 'Rue de Carthage, Tunis');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'DELETE',
            '/api/addresses/'.$address->getId(),
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NO_CONTENT
        );

        $this->entityManager->clear();

        $deleted = $this->entityManager
            ->getRepository(Address::class)
            ->find($address->getId());

        self::assertNull($deleted);
    }

    public function testUserCannotDeleteAnotherUsersAddress(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('Test Client');
        $otherUser = $this->createTestUser('Other Client');

        $address = $this->createAddress($otherUser, 'Bureau', 'Avenue Habib Bourguiba, Tunis');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'DELETE',
            '/api/addresses/'.$address->getId(),
            server: [
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ]
        );

        self::assertResponseStatusCodeSame(
            Response::HTTP_NOT_FOUND
        );

        $this->entityManager->clear();

        $stillThere = $this->entityManager
            ->getRepository(Address::class)
            ->find($address->getId());

        self::assertNotNull($stillThere);
    }

    private function createAddress(
        User $user,
        string $label,
        string $addressLine,
        bool $isDefault = false,
    ): Address {
        $address = (new Address())
            ->setUser($user)
            ->setLabel($label)
            ->setAddressLine($addressLine)
            ->setDefault($isDefault);

        $this->entityManager->persist($address);
        $this->entityManager->flush();

        return $address;
    }

    private function createTestUser(string $name): User
    {
        $user = new User();

        $user->setName($name);
        $user->setPhone($this->uniquePhone());
        $user->setRoles(['ROLE_USER']);
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
        self::assertArrayHasKey('token', $loginData);

        return $loginData['token'];
    }

    private function uniquePhone(): string
    {
        return '7'.random_int(
            10000000,
            99999999
        );
    }
}
