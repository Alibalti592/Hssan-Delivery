<?php

namespace App\Tests\Integration;

use App\Entity\CourierLocation;
use App\Entity\Delivery;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\DeliveryType;
use App\Enum\OrderStatus;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * "Suivre ma commande": the client sees where their courier is, only while
 * that courier is on their order.
 */
final class OrderCourierLocationApiTest extends WebTestCase
{
    private KernelBrowser $client;
    private EntityManagerInterface $entityManager;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
    }

    public function testTheClientSeesTheirCourierOnTheWay(): void
    {
        $client = $this->user('ROLE_CLIENT');
        $courier = $this->user('ROLE_LIVREUR');
        $order = $this->order($client, $courier, DeliveryStatus::ON_THE_WAY);
        $this->locate($courier, 37.2746, 9.8739);

        $this->get($client, $order);

        self::assertResponseIsSuccessful();
        $data = json_decode((string) $this->client->getResponse()->getContent(), true);
        self::assertSame(37.2746, $data['latitude']);
        self::assertSame(9.8739, $data['longitude']);
        self::assertNotNull($data['updatedAt']);
    }

    public function testNothingBeforeTheCourierAcceptsOrAfterDelivery(): void
    {
        $client = $this->user('ROLE_CLIENT');

        foreach ([DeliveryStatus::ASSIGNED, DeliveryStatus::DELIVERED, DeliveryStatus::CANCELLED] as $status) {
            $courier = $this->user('ROLE_LIVREUR');
            $order = $this->order($client, $courier, $status);
            $this->locate($courier, 37.27, 9.87);

            $this->get($client, $order);

            self::assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND, $status->value);
        }
    }

    public function testAnotherClientCannotSeeTheCourier(): void
    {
        $courier = $this->user('ROLE_LIVREUR');
        $order = $this->order($this->user('ROLE_CLIENT'), $courier, DeliveryStatus::ON_THE_WAY);
        $this->locate($courier, 37.27, 9.87);

        $this->get($this->user('ROLE_CLIENT'), $order);

        self::assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND);
    }

    public function testNothingWhileTheCourierHasNotReportedAPosition(): void
    {
        $client = $this->user('ROLE_CLIENT');
        $order = $this->order($client, $this->user('ROLE_LIVREUR'), DeliveryStatus::PICKED_UP);

        $this->get($client, $order);

        self::assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND);
    }

    private function get(User $user, Order $order): void
    {
        $this->client->request('POST', '/api/auth/login', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'phone' => $user->getPhone(),
            'password' => 'password123',
        ]));
        self::assertResponseIsSuccessful();
        $token = json_decode((string) $this->client->getResponse()->getContent(), true)['token'];

        $this->client->request('GET', '/api/orders/'.$order->getId().'/courier-location', server: [
            'HTTP_AUTHORIZATION' => 'Bearer '.$token,
        ]);
    }

    private function order(User $client, User $courier, DeliveryStatus $status): Order
    {
        // Fetched again: a request in between leaves earlier ones detached.
        $client = $this->entityManager->find(User::class, $client->getId());
        $courier = $this->entityManager->find(User::class, $courier->getId());
        $zone = (new DeliveryZone())->setName('Suivi '.random_int(1000000, 999999999))->setFee('4.000');
        $order = new Order();
        $order->setUser($client);
        $order->setDeliveryType(DeliveryType::PARCEL);
        $order->setPickupAddress('Rue de Marseille');
        $order->setDeliveryAddress('Corniche');
        $order->setRecipientName('Amira');
        $order->setRecipientPhone('98141009');
        $order->setDeliveryZone($zone);
        $order->setDeliveryFee('4.000');
        $order->setTotalAmount('4.000');
        $order->setStatus(OrderStatus::CONFIRMED);

        $delivery = new Delivery();
        $delivery->setOrder($order);
        $delivery->setCourier($courier);
        $delivery->setStatus($status);
        $order->setDelivery($delivery);

        $this->entityManager->persist($zone);
        $this->entityManager->persist($order);
        $this->entityManager->persist($delivery);
        $this->entityManager->flush();

        return $order;
    }

    private function locate(User $courier, float $lat, float $lng): void
    {
        $courier = $this->entityManager->find(User::class, $courier->getId());
        $location = (new CourierLocation())->setCourier($courier)->setLatitude($lat)->setLongitude($lng);
        $this->entityManager->persist($location);
        $this->entityManager->flush();
    }

    private function user(string $role): User
    {
        $user = new User();
        $user->setName('Suivi '.$role);
        $user->setPhone((string) random_int(20000000, 99999999));
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123'));
        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }
}
