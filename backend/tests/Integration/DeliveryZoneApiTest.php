<?php

namespace App\Tests\Integration;

use App\Entity\DeliveryZone;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * Covers the public GET /api/delivery-zones endpoint (DeliveryZoneController)
 * that a signed-in client sees, as distinct from the admin CRUD surface
 * already covered by AdminDeliveryZoneApiTest.
 */
final class DeliveryZoneApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    public function testSignedInClientCanListDeliveryZonesOrderedByName(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_USER', 'Test Client');

        $this->createDeliveryZone('Zone B', '5.000');
        $this->createDeliveryZone('Zone A', '4.000');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/delivery-zones',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertIsArray($response);

        $names = array_column($response, 'name');

        self::assertContains('Zone A', $names);
        self::assertContains('Zone B', $names);
        self::assertSame(
            array_values(array_intersect($names, ['Zone A', 'Zone B'])),
            ['Zone A', 'Zone B'],
            'Zones should be ordered alphabetically by name.'
        );

        $zone = $response[array_search('Zone A', $names, true)];

        self::assertArrayHasKey('id', $zone);
        self::assertSame('4.000', $zone['fee']);
    }

    public function testListingDeliveryZonesWithoutAuthenticationIsRejected(): void
    {
        $client = static::createClient();

        $client->request('GET', '/api/delivery-zones');

        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    private function createDeliveryZone(string $name, string $fee): DeliveryZone
    {
        $zone = (new DeliveryZone())
            ->setName($name)
            ->setFee($fee);

        $this->entityManager->persist($zone);
        $this->entityManager->flush();

        return $zone;
    }

    private function createTestUser(string $role, string $name): User
    {
        $user = new User();

        $user->setName($name);
        $user->setPhone($this->uniquePhone());
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());

        $passwordHasher = self::getContainer()->get(UserPasswordHasherInterface::class);

        $user->setPassword($passwordHasher->hashPassword($user, 'password123'));

        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    private function authenticateClient(KernelBrowser $client, User $user): string
    {
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
        return '6'.random_int(10000000, 99999999);
    }
}
