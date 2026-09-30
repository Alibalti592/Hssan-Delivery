<?php

namespace App\Tests\Integration;

use App\Entity\Delivery;
use App\Entity\DeliveryZone;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * Saved addresses carry their delivery zone and map pin, and orders keep
 * the pins the client placed so the courier can navigate to them.
 */
final class AddressLocationApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;
    private KernelBrowser $client;
    private User $customer;
    private string $token;
    private DeliveryZone $zone;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        $this->customer = $this->createUser('ROLE_CLIENT');
        $this->token = $this->authenticate($this->customer);

        $this->zone = (new DeliveryZone())->setName('Pin Zone '.random_int(1000000, 999999999))->setFee('4.500');
        $this->entityManager->persist($this->zone);
        $this->entityManager->flush();
    }

    public function testAnAddressRemembersItsZoneAndPin(): void
    {
        $this->client->request('POST', '/api/addresses', server: $this->headers($this->token), content: json_encode([
            'label' => 'Maison',
            'addressLine' => 'Rue de Marseille, Bizerte',
            'deliveryZoneId' => $this->zone->getId(),
            'latitude' => 37.2744,
            'longitude' => 9.8739,
        ]));

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        $address = json_decode($this->client->getResponse()->getContent(), true);
        self::assertSame($this->zone->getId(), $address['deliveryZoneId']);
        self::assertSame($this->zone->getName(), $address['deliveryZoneName']);
        self::assertSame('4.500', $address['deliveryZoneFee']);
        self::assertSame(37.2744, $address['latitude']);
        self::assertSame(9.8739, $address['longitude']);

        // Moving the pin and dropping the zone on edit.
        $this->client->request('PUT', '/api/addresses/'.$address['id'], server: $this->headers($this->token), content: json_encode([
            'label' => 'Maison',
            'addressLine' => 'Rue de Marseille, Bizerte',
            'latitude' => 37.28,
            'longitude' => 9.87,
        ]));

        self::assertResponseIsSuccessful();
        $updated = json_decode($this->client->getResponse()->getContent(), true);
        self::assertNull($updated['deliveryZoneId']);
        self::assertSame(37.28, $updated['latitude']);
    }

    public function testAnAddressWithoutZoneOrPinStillWorks(): void
    {
        $this->client->request('POST', '/api/addresses', server: $this->headers($this->token), content: json_encode([
            'label' => 'Bureau',
            'addressLine' => 'Avenue Habib Bourguiba',
        ]));

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        $address = json_decode($this->client->getResponse()->getContent(), true);
        self::assertNull($address['deliveryZoneId']);
        self::assertNull($address['latitude']);
    }

    public function testHalfAPinOrAnUnknownZoneIsRejected(): void
    {
        $this->client->request('POST', '/api/addresses', server: $this->headers($this->token), content: json_encode([
            'label' => 'Maison',
            'addressLine' => 'Rue X',
            'latitude' => 37.2,
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);

        $this->client->request('POST', '/api/addresses', server: $this->headers($this->token), content: json_encode([
            'label' => 'Maison',
            'addressLine' => 'Rue X',
            'latitude' => 137.2,
            'longitude' => 9.8,
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);

        $this->client->request('POST', '/api/addresses', server: $this->headers($this->token), content: json_encode([
            'label' => 'Maison',
            'addressLine' => 'Rue X',
            'deliveryZoneId' => 999999999,
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
    }

    public function testTheCourierGetsTheParcelPinsToNavigateTo(): void
    {
        $this->client->request('POST', '/api/orders/parcels', server: $this->headers($this->token), content: json_encode([
            'pickupAddress' => 'Rue de Marseille',
            'pickupLatitude' => 37.2744,
            'pickupLongitude' => 9.8739,
            'deliveryAddress' => 'Corniche',
            'deliveryLatitude' => 37.29,
            'deliveryLongitude' => 9.86,
            'recipientName' => 'Sami',
            'recipientPhone' => '22123456',
            'deliveryZoneId' => $this->zone->getId(),
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        $created = json_decode($this->client->getResponse()->getContent(), true);
        $orderId = $created['id'];

        // The client's own order carries the pins too, for its tracking map.
        self::assertSame(37.2744, $created['pickupLatitude']);
        self::assertSame(9.86, $created['deliveryLongitude']);

        $courier = $this->createUser('ROLE_LIVREUR');
        $delivery = $this->entityManager->getRepository(Delivery::class)->findOneBy(['order' => $orderId]);
        $delivery->setCourier($this->entityManager->getRepository(User::class)->find($courier->getId()));
        $delivery->setStatus(DeliveryStatus::ASSIGNED);
        $this->entityManager->flush();

        $this->client->request('GET', '/api/deliveries/mine', server: $this->headers($this->authenticate($courier)));
        $job = json_decode($this->client->getResponse()->getContent(), true)['items'][0]['order'];

        self::assertSame(37.2744, $job['pickupLatitude']);
        self::assertSame(9.8739, $job['pickupLongitude']);
        self::assertSame(37.29, $job['deliveryLatitude']);
        self::assertSame(9.86, $job['deliveryLongitude']);
    }

    public function testAnOrderWithHalfAPinIsRejected(): void
    {
        $this->client->request('POST', '/api/orders/parcels', server: $this->headers($this->token), content: json_encode([
            'pickupAddress' => 'Rue de Marseille',
            'deliveryAddress' => 'Corniche',
            'deliveryLongitude' => 9.86,
            'recipientName' => 'Sami',
            'recipientPhone' => '22123456',
            'deliveryZoneId' => $this->zone->getId(),
        ]));

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    /**
     * @return array<string, string>
     */
    private function headers(string $token): array
    {
        return ['CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => 'Bearer '.$token];
    }

    private function createUser(string $role): User
    {
        $user = new User();
        $user->setName($role);
        $user->setPhone('2'.random_int(10000000, 99999999));
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123'));

        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    private function authenticate(User $user): string
    {
        $this->client->request(
            'POST',
            '/api/auth/login',
            server: ['CONTENT_TYPE' => 'application/json'],
            content: json_encode(['phone' => $user->getPhone(), 'password' => 'password123'])
        );
        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        return json_decode($this->client->getResponse()->getContent(), true)['token'];
    }
}
