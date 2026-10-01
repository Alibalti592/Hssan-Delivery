<?php

namespace App\Tests\Integration;

use App\Entity\Address;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\OrderStatus;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * "Supprimer mon compte": the person's data goes, their past orders stay.
 */
final class AccountDeletionApiTest extends WebTestCase
{
    private KernelBrowser $client;
    private EntityManagerInterface $entityManager;
    private DeliveryZone $zone;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        self::getContainer()->get('cache.rate_limiter')->clear();

        $this->zone = new DeliveryZone();
        $this->zone->setName('Deletion Zone '.random_int(1000000, 999999999));
        $this->zone->setFee('4.000');
        $this->entityManager->persist($this->zone);
        $this->entityManager->flush();
    }

    public function testDeletingTheAccountRemovesThePersonButKeepsTheOrders(): void
    {
        $user = $this->createUser('ROLE_CLIENT');
        $phone = $user->getPhone();
        $token = $this->login($phone);

        $this->client->request('POST', '/api/addresses', server: $this->headers($token), content: json_encode([
            'label' => 'Maison',
            'addressLine' => '12 Rue de Marseille',
            'deliveryZoneId' => $this->zone->getId(),
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        $orderId = $this->placeParcel($token);
        $this->finish($orderId);

        $this->client->request('DELETE', '/api/auth/me', server: $this->headers($token), content: json_encode([
            'password' => 'password123',
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $this->entityManager->clear();
        $order = $this->entityManager->getRepository(Order::class)->find($orderId);
        self::assertNotNull($order, 'The order is kept.');
        self::assertSame('Compte supprimé', $order->getUser()->getName());
        self::assertStringStartsWith('supprime-', $order->getUser()->getPhone());
        self::assertFalse($order->getUser()->isActive());
        self::assertSame([], $this->entityManager->getRepository(Address::class)->findBy(['user' => $order->getUser()]));

        // The old credentials no longer work, and the number is free again
        // (for a new install: without the deleted account's login cookie).
        $this->client->getCookieJar()->clear();
        $this->client->request('POST', '/api/auth/login', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'phone' => $phone,
            'password' => 'password123',
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);

        $this->client->request('POST', '/api/auth/register', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'name' => 'Nouveau Client',
            'phone' => $phone,
            'password' => 'password456',
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
    }

    public function testTheWrongPasswordDeletesNothing(): void
    {
        $user = $this->createUser('ROLE_CLIENT');
        $token = $this->login($user->getPhone());

        $this->client->request('DELETE', '/api/auth/me', server: $this->headers($token), content: json_encode([
            'password' => 'not-my-password',
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
        self::assertSame('Mot de passe incorrect.', $this->message());

        $this->entityManager->clear();
        self::assertSame('Deletion Client', $this->entityManager->getRepository(User::class)->find($user->getId())->getName());
    }

    public function testAnOrderInProgressMustFinishFirst(): void
    {
        $user = $this->createUser('ROLE_CLIENT');
        $token = $this->login($user->getPhone());
        $this->placeParcel($token);

        $this->client->request('DELETE', '/api/auth/me', server: $this->headers($token), content: json_encode([
            'password' => 'password123',
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_CONFLICT);
        self::assertStringContainsString('commande en cours', $this->message());
    }

    public function testAnAdminCannotDeleteThemselvesFromTheApp(): void
    {
        $admin = $this->createUser('ROLE_ADMIN');
        $token = $this->login($admin->getPhone());

        $this->client->request('DELETE', '/api/auth/me', server: $this->headers($token), content: json_encode([
            'password' => 'password123',
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
    }

    private function placeParcel(string $token): int
    {
        $this->client->request('POST', '/api/orders/parcels', server: $this->headers($token), content: json_encode([
            'pickupAddress' => 'Rue de Marseille',
            'deliveryAddress' => 'Corniche',
            'recipientName' => 'Sami',
            'recipientPhone' => '22123456',
            'deliveryZoneId' => $this->zone->getId(),
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);

        return json_decode((string) $this->client->getResponse()->getContent(), true)['id'];
    }

    private function finish(int $orderId): void
    {
        $order = $this->entityManager->getRepository(Order::class)->find($orderId);
        $order->setStatus(OrderStatus::COMPLETED);
        $order->getDelivery()->setStatus(DeliveryStatus::DELIVERED);
        $this->entityManager->flush();
    }

    private function createUser(string $role): User
    {
        $user = new User();
        $user->setName('Deletion Client');
        $user->setPhone((string) random_int(20000000, 99999999));
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123'));
        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    private function login(string $phone): string
    {
        $this->client->request('POST', '/api/auth/login', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'phone' => $phone,
            'password' => 'password123',
        ]));
        self::assertResponseIsSuccessful();

        return json_decode((string) $this->client->getResponse()->getContent(), true)['token'];
    }

    /**
     * @return array<string, string>
     */
    private function headers(string $token): array
    {
        return ['CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => 'Bearer '.$token];
    }

    private function message(): string
    {
        return json_decode((string) $this->client->getResponse()->getContent(), true)['message'];
    }
}
