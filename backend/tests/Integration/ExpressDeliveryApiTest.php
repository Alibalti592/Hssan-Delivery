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
 * Express delivery: 1 DT more, first in the dispatch queue, and a courier
 * on a standard delivery can take one express order on top of it.
 */
final class ExpressDeliveryApiTest extends WebTestCase
{
    private KernelBrowser $client;
    private EntityManagerInterface $entityManager;
    private DeliveryZone $zone;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        $this->zone = (new DeliveryZone())->setName('Express Zone '.random_int(100000, 999999))->setFee('4.000');
        $this->entityManager->persist($this->zone);
        $this->entityManager->flush();
    }

    public function testExpressCostsOneDinarMore(): void
    {
        $token = $this->login('ROLE_CLIENT');

        $standard = $this->parcel($token);
        self::assertSame('STANDARD', $standard['deliverySpeed']);
        self::assertSame('4.000', $standard['deliveryFee']);
        self::assertSame('4.000', $standard['totalAmount']);

        $express = $this->parcel($token, 'EXPRESS');
        self::assertSame('EXPRESS', $express['deliverySpeed']);
        self::assertSame('5.000', $express['deliveryFee']);
        self::assertSame('5.000', $express['totalAmount']);
    }

    public function testAnUnknownSpeedIsRejected(): void
    {
        $this->client->request('POST', '/api/orders/parcels', server: $this->auth($this->login('ROLE_CLIENT')), content: json_encode($this->parcelBody('TURBO')));

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    public function testExpressOrdersComeFirstInTheQueue(): void
    {
        $token = $this->login('ROLE_CLIENT');
        $standard = $this->parcel($token);
        $express = $this->parcel($token, 'EXPRESS');

        $this->client->request('GET', '/api/admin/deliveries/waiting', server: $this->auth($this->login('ROLE_ADMIN')));
        self::assertResponseIsSuccessful();
        $speeds = array_map(static fn ($d) => $d['order']['deliverySpeed'], $this->json());

        // Ours is there, and no express order comes after a standard one.
        self::assertContains($express['id'], array_column($this->json(), 'orderId'));
        $firstStandard = array_search('STANDARD', $speeds, true);
        if (false !== $firstStandard) {
            self::assertNotContains('EXPRESS', array_slice($speeds, $firstStandard));
        }
        self::assertNotEmpty($standard['id']);
    }

    public function testACourierCanCarrySeveralOrdersExpressOrNot(): void
    {
        $client = $this->login('ROLE_CLIENT');
        $admin = $this->login('ROLE_ADMIN');
        $courierId = $this->courier();

        foreach (['STANDARD', 'STANDARD', 'EXPRESS', 'EXPRESS'] as $speed) {
            $order = $this->parcel($client, $speed);
            $this->assign($admin, $order['deliveryId'], $courierId);
            self::assertResponseIsSuccessful();
        }

        // The admin map counts what they carry.
        $this->client->request('GET', '/api/admin/couriers/locations', server: $this->auth($admin));
        $entry = array_values(array_filter($this->json(), static fn ($c) => $c['courierId'] === $courierId))[0];
        self::assertSame(4, $entry['activeDeliveries']);
    }

    /** @return array<string, mixed> */
    private function parcelBody(string $speed = 'STANDARD'): array
    {
        return [
            'pickupAddress' => 'Rue de Marseille',
            'deliveryAddress' => 'Corniche',
            'recipientName' => 'Sami',
            'recipientPhone' => '22123456',
            'deliveryZoneId' => $this->zone->getId(),
            'deliverySpeed' => $speed,
        ];
    }

    /** @return array<string, mixed> */
    private function parcel(string $token, string $speed = 'STANDARD'): array
    {
        $this->client->request('POST', '/api/orders/parcels', server: $this->auth($token), content: json_encode($this->parcelBody($speed)));
        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);

        return $this->json();
    }

    private function assign(string $adminToken, int $deliveryId, int $courierId): void
    {
        $this->client->request('POST', sprintf('/api/deliveries/%d/assign/%d', $deliveryId, $courierId), server: $this->auth($adminToken));
    }

    private function courier(): int
    {
        return $this->createUser('ROLE_LIVREUR')->getId();
    }

    private function createUser(string $role): User
    {
        $user = new User();
        $user->setName('Express '.$role);
        $user->setPhone((string) random_int(20000000, 99999999));
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123'));
        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    private function login(string $role): string
    {
        $user = $this->createUser($role);
        $this->client->request('POST', '/api/auth/login', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'phone' => $user->getPhone(),
            'password' => 'password123',
        ]));
        self::assertResponseIsSuccessful();

        return $this->json()['token'];
    }

    /** @return array<string, string> */
    private function auth(string $token): array
    {
        return ['HTTP_AUTHORIZATION' => 'Bearer '.$token, 'CONTENT_TYPE' => 'application/json'];
    }

    /** @return array<string, mixed> */
    private function json(): array
    {
        return json_decode((string) $this->client->getResponse()->getContent(), true);
    }
}
