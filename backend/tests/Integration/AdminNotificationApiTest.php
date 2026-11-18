<?php

namespace App\Tests\Integration;

use App\Entity\DeviceToken;
use App\Entity\Promotion;
use App\Entity\User;
use App\Enum\DiscountType;
use App\Repository\DeviceTokenRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * The admin's "Notifications" page: one notification to every customer's
 * phone, kept in a history, never twice by a double click.
 */
final class AdminNotificationApiTest extends WebTestCase
{
    private KernelBrowser $client;
    private EntityManagerInterface $entityManager;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        // Earlier runs' sends would trip the one-a-minute guard.
        $this->entityManager->createQuery('UPDATE App\Entity\PushCampaign c SET c.sentAt = :old WHERE c.sentAt > :old')
            ->setParameter('old', new \DateTimeImmutable('-1 hour'))
            ->execute();
    }

    public function testSendsToEveryCustomerPhoneAndKeepsIt(): void
    {
        $customer = $this->createUser('ROLE_CLIENT');
        $courier = $this->createUser('ROLE_LIVREUR');
        $customerToken = $this->deviceToken($customer);
        $courierToken = $this->deviceToken($courier);
        $promotion = (new Promotion())
            ->setTitle('Flash Hour')
            ->setDiscountType(DiscountType::PERCENTAGE)
            ->setDiscountValue('35.000')
            ->setPromoCode('RB35')
            ->setStartAt(new \DateTimeImmutable('-1 hour'))
            ->setIsActive(true);
        $this->entityManager->persist($promotion);
        $this->entityManager->flush();

        $tokens = self::getContainer()->get(DeviceTokenRepository::class)->findClientTokenStrings();
        self::assertContains($customerToken, $tokens);
        self::assertNotContains($courierToken, $tokens, 'couriers get no offers');

        $admin = $this->login($this->createUser('ROLE_ADMIN'));
        $before = $this->request('GET', $admin);
        self::assertResponseIsSuccessful();
        self::assertSame(count($tokens), $before['reachableDevices']);

        $sent = $this->request('POST', $admin, [
            'title' => '  ⚡ FLASH HOUR : -35% ! 🔥 ',
            'body' => "🎟️ Code promo : RB35\n📲 Commandez vite sur Delivery Hassen !",
            'promotionId' => $promotion->getId(),
        ]);
        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        self::assertSame('⚡ FLASH HOUR : -35% ! 🔥', $sent['title']);
        self::assertSame($promotion->getId(), $sent['promotionId']);
        self::assertSame('Flash Hour', $sent['promotionTitle']);
        self::assertSame(count($tokens), $sent['recipients']);
        // No Firebase key in tests: push is off, so nothing was delivered.
        self::assertNull($sent['delivered']);

        $after = $this->request('GET', $admin);
        self::assertSame($sent['id'], $after['campaigns'][0]['id']);

        // A double click: the second one is refused.
        $this->request('POST', $admin, ['title' => 'Encore', 'body' => 'Encore']);
        self::assertResponseStatusCodeSame(Response::HTTP_TOO_MANY_REQUESTS);
    }

    public function testRefusesAnEmptyOrTooLongNotification(): void
    {
        $admin = $this->login($this->createUser('ROLE_ADMIN'));

        $this->request('POST', $admin, ['title' => '  ', 'body' => 'Texte']);
        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);

        $this->request('POST', $admin, ['title' => str_repeat('a', 66), 'body' => 'Texte']);
        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);

        $this->request('POST', $admin, ['title' => 'Titre', 'body' => 'Texte', 'promotionId' => 999999999]);
        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    public function testOnlyForAdmins(): void
    {
        $customer = $this->login($this->createUser('ROLE_CLIENT'));

        $this->request('POST', $customer, ['title' => 'Titre', 'body' => 'Texte']);
        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);
    }

    /**
     * @param array<string, mixed>|null $body
     *
     * @return array<string, mixed>
     */
    private function request(string $method, string $token, ?array $body = null): array
    {
        $this->client->request($method, '/api/admin/notifications', server: [
            'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            'CONTENT_TYPE' => 'application/json',
        ], content: null === $body ? null : json_encode($body));

        return json_decode((string) $this->client->getResponse()->getContent(), true) ?? [];
    }

    private function deviceToken(User $user): string
    {
        $token = 'test-'.bin2hex(random_bytes(12));
        $this->entityManager->persist((new DeviceToken())->setUser($user)->setToken($token)->setPlatform('android'));
        $this->entityManager->flush();

        return $token;
    }

    private function createUser(string $role): User
    {
        $user = new User();
        $user->setName("Notif {$role}");
        $user->setPhone((string) random_int(20000000, 99999999));
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123'));
        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    private function login(User $user): string
    {
        $this->client->request('POST', '/api/auth/login', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'phone' => $user->getPhone(),
            'password' => 'password123',
        ]));
        self::assertResponseIsSuccessful();

        return json_decode((string) $this->client->getResponse()->getContent(), true)['token'];
    }
}
