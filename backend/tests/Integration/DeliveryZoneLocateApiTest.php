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
 * Zones placed on the map (a center and a radius): the admin places them,
 * and an address pin gets the zone covering it automatically.
 */
final class DeliveryZoneLocateApiTest extends WebTestCase
{
    private KernelBrowser $client;
    private EntityManagerInterface $entityManager;

    /** A spot of open sea per run, so zones from other runs never overlap. */
    private float $lat;
    private float $lng;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        $this->lat = -40 + random_int(0, 100000) / 10000;
        $this->lng = -120 + random_int(0, 100000) / 10000;
    }

    public function testAPinGetsTheZoneCoveringIt(): void
    {
        $centre = $this->placedZone('Centre', $this->lat, $this->lng, 1.0);
        // A wider zone around it, centered 2 km east.
        $outskirts = $this->placedZone('Banlieue', $this->lat, $this->lng + 0.0236, 4.0);
        $this->zone('Pas placée');

        $token = $this->login('ROLE_CLIENT');

        // 300 m from Centre's center: inside both, Centre's center is nearer.
        self::assertSame($centre->getId(), $this->locate($token, $this->lat + 0.0027, $this->lng)['id']);
        // 3 km east: only the outskirts cover it.
        self::assertSame($outskirts->getId(), $this->locate($token, $this->lat, $this->lng + 0.0354)['id']);
        self::assertSame(['id', 'name', 'fee'], array_keys($this->locate($token, $this->lat, $this->lng)));
    }

    public function testAPinOutsideEveryZoneIsA404(): void
    {
        $this->placedZone('Centre', $this->lat, $this->lng, 1.0);

        // 20 km south.
        $this->locate($this->login('ROLE_CLIENT'), $this->lat - 0.18, $this->lng);

        self::assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND);
        self::assertSame('Aucune zone ne couvre cette adresse. Choisissez-la.', $this->json()['message']);
    }

    public function testAnInvalidPositionIsA400(): void
    {
        $token = $this->login('ROLE_CLIENT');

        $this->client->request('GET', '/api/delivery-zones/locate?latitude=abc&longitude=10', server: $this->auth($token));
        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);

        $this->client->request('GET', '/api/delivery-zones/locate?latitude=95&longitude=10', server: $this->auth($token));
        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
    }

    public function testTheAdminPlacesAZoneOnTheMap(): void
    {
        $token = $this->login('ROLE_ADMIN');
        $name = 'Zone carte '.random_int(100000, 999999);

        $this->client->request('POST', '/api/admin/delivery-zones', server: $this->auth($token) + ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'name' => $name,
            'fee' => '4.000',
            'latitude' => $this->lat,
            'longitude' => $this->lng,
            'radiusKm' => 1.5,
        ]));

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        $created = $this->json();
        self::assertSame($this->lat, $created['latitude']);
        self::assertSame($this->lng, $created['longitude']);
        self::assertSame(1.5, $created['radiusKm']);

        // And takes it off the map again.
        $this->client->request('PUT', '/api/admin/delivery-zones/'.$created['id'], server: $this->auth($token) + ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'name' => $name,
            'fee' => '4.000',
        ]));

        self::assertResponseIsSuccessful();
        self::assertNull($this->json()['radiusKm']);
    }

    public function testAPartlyPlacedZoneIsRejected(): void
    {
        $this->client->request('POST', '/api/admin/delivery-zones', server: $this->auth($this->login('ROLE_ADMIN')) + ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'name' => 'Zone sans rayon '.random_int(100000, 999999),
            'fee' => '4.000',
            'latitude' => $this->lat,
            'longitude' => $this->lng,
        ]));

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    /** @return array<string, mixed> */
    private function locate(string $token, float $lat, float $lng): array
    {
        $this->client->request('GET', sprintf('/api/delivery-zones/locate?latitude=%F&longitude=%F', $lat, $lng), server: $this->auth($token));

        return $this->json();
    }

    private function placedZone(string $name, float $lat, float $lng, float $radiusKm): DeliveryZone
    {
        return $this->zone($name, $lat, $lng, $radiusKm);
    }

    private function zone(string $name, ?float $lat = null, ?float $lng = null, ?float $radiusKm = null): DeliveryZone
    {
        $zone = (new DeliveryZone())
            ->setName($name.' '.random_int(100000, 999999))
            ->setFee('4.000')
            ->setArea($lat, $lng, $radiusKm);
        $this->entityManager->persist($zone);
        $this->entityManager->flush();

        return $zone;
    }

    private function login(string $role): string
    {
        $user = new User();
        $user->setName('Zone '.$role);
        $user->setPhone((string) random_int(20000000, 99999999));
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123'));
        $this->entityManager->persist($user);
        $this->entityManager->flush();

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
        return ['HTTP_AUTHORIZATION' => 'Bearer '.$token];
    }

    /** @return array<string, mixed> */
    private function json(): array
    {
        return json_decode((string) $this->client->getResponse()->getContent(), true);
    }
}
