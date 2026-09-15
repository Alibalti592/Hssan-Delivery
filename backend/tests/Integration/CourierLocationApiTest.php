<?php

namespace App\Tests\Integration;

use App\Entity\CourierLocation;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class CourierLocationApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    public function testCourierCanReportLocation(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $courier = $this->createTestUser('ROLE_LIVREUR', 'Reporting Courier');

        $token = $this->authenticateClient($client, $courier);

        $client->request(
            'POST',
            '/api/couriers/location',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'latitude' => 37.2746,
                'longitude' => 9.8739,
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $this->entityManager->clear();

        $location = $this->entityManager->getRepository(CourierLocation::class)->findOneBy(['courier' => $courier]);

        self::assertNotNull($location);
        self::assertSame(37.2746, $location->getLatitude());
        self::assertSame(9.8739, $location->getLongitude());
    }

    public function testReportingLocationTwiceUpdatesTheSameRow(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $courier = $this->createTestUser('ROLE_LIVREUR', 'Upsert Courier');

        $token = $this->authenticateClient($client, $courier);

        $client->request(
            'POST',
            '/api/couriers/location',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode(['latitude' => 36.8, 'longitude' => 10.18])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $client->request(
            'POST',
            '/api/couriers/location',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode(['latitude' => 36.9, 'longitude' => 10.2])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $this->entityManager->clear();

        $locations = $this->entityManager->getRepository(CourierLocation::class)->findBy(['courier' => $courier]);

        self::assertCount(1, $locations);
        self::assertSame(36.9, $locations[0]->getLatitude());
        self::assertSame(10.2, $locations[0]->getLongitude());
    }

    public function testInvalidLatitudeIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $courier = $this->createTestUser('ROLE_LIVREUR', 'Invalid Lat Courier');

        $token = $this->authenticateClient($client, $courier);

        $client->request(
            'POST',
            '/api/couriers/location',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode(['latitude' => 200, 'longitude' => 10.18])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertSame('Validation failed.', $response['message']);
    }

    public function testInvalidLongitudeIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $courier = $this->createTestUser('ROLE_LIVREUR', 'Invalid Lng Courier');

        $token = $this->authenticateClient($client, $courier);

        $client->request(
            'POST',
            '/api/couriers/location',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode(['latitude' => 36.8, 'longitude' => -200])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    public function testMissingCoordinatesAreRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $courier = $this->createTestUser('ROLE_LIVREUR', 'Missing Coords Courier');

        $token = $this->authenticateClient($client, $courier);

        $client->request(
            'POST',
            '/api/couriers/location',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    public function testNonCourierCannotReportLocation(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_USER', 'Plain Client');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'POST',
            '/api/couriers/location',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode(['latitude' => 36.8, 'longitude' => 10.18])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);
    }

    public function testAdminCanListCourierLocations(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $courierWithLocation = $this->createTestUser('ROLE_LIVREUR', 'Located Courier');
        $courierWithoutLocation = $this->createTestUser('ROLE_LIVREUR', 'Unlocated Courier');

        $courierToken = $this->authenticateClient($client, $courierWithLocation);

        $client->request(
            'POST',
            '/api/couriers/location',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$courierToken,
            ],
            content: json_encode(['latitude' => 36.8, 'longitude' => 10.18])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'GET',
            '/api/admin/couriers/locations',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertIsArray($response);

        $byId = [];
        foreach ($response as $entry) {
            $byId[$entry['courierId']] = $entry;
        }

        self::assertArrayHasKey($courierWithLocation->getId(), $byId);
        self::assertArrayHasKey($courierWithoutLocation->getId(), $byId);

        self::assertSame(36.8, $byId[$courierWithLocation->getId()]['latitude']);
        self::assertSame(10.18, $byId[$courierWithLocation->getId()]['longitude']);
        self::assertNotNull($byId[$courierWithLocation->getId()]['updatedAt']);

        self::assertNull($byId[$courierWithoutLocation->getId()]['latitude']);
        self::assertSame('OFFLINE', $byId[$courierWithoutLocation->getId()]['status']);

        self::assertArrayNotHasKey('phone', $byId[$courierWithLocation->getId()]);
    }

    /**
     * CourierLocationService::listForAdmin() used to call
     * findOneByCourier()/findActiveForCourier() once per courier inside
     * array_map — for N couriers that's 1 (paginate) + 2N queries. Both
     * are now batched into a single query each regardless of N. Counted
     * via Doctrine's own debug middleware (doctrine.debug_data_holder)
     * rather than mocking anything, so this fails for real if the
     * batching regresses.
     */
    public function testListingCourierLocationsDoesNotIssueAQueryPerCourier(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $couriers = [
            $this->createTestUser('ROLE_LIVREUR', 'Query Count Courier 1'),
            $this->createTestUser('ROLE_LIVREUR', 'Query Count Courier 2'),
            $this->createTestUser('ROLE_LIVREUR', 'Query Count Courier 3'),
        ];

        foreach ($couriers as $i => $courier) {
            $courierToken = $this->authenticateClient($client, $courier);

            $client->request(
                'POST',
                '/api/couriers/location',
                server: [
                    'CONTENT_TYPE' => 'application/json',
                    'HTTP_AUTHORIZATION' => 'Bearer '.$courierToken,
                ],
                content: json_encode(['latitude' => 36.8 + $i, 'longitude' => 10.18 + $i])
            );

            self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);
        }

        $adminToken = $this->authenticateClient($client, $admin);

        // Fetched fresh immediately before/after the request rather than
        // reused across it — see OrderApiTest::testListingOrdersDoesNotIssueAQueryPerOrder
        // for why a reference held from before the request isn't reliable.
        self::getContainer()->get('doctrine.debug_data_holder')->reset();

        $client->request(
            'GET',
            '/api/admin/couriers/locations',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode($client->getResponse()->getContent(), true);
        self::assertGreaterThanOrEqual(3, count($response));

        $queries = self::getContainer()->get('doctrine.debug_data_holder')->getData()['default'] ?? [];
        $queryCount = count($queries);

        self::assertGreaterThan(
            0,
            $queryCount,
            'Expected doctrine.debug_data_holder to have recorded this request\'s queries.'
        );

        // Flat regardless of courier count: reload the JWT's user, the
        // paginated courier list, its COUNT, one batch query for
        // locations, and one batch query for active deliveries — not two
        // queries per courier.
        self::assertLessThanOrEqual(
            6,
            $queryCount,
            "Expected a small, constant number of queries regardless of courier count, got {$queryCount}."
        );
    }

    public function testNonAdminCannotListCourierLocations(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_USER', 'Plain Client');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/admin/couriers/locations',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);
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
        return '2'.random_int(10000000, 99999999);
    }
}
