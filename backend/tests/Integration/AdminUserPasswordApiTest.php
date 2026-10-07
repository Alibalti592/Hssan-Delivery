<?php

namespace App\Tests\Integration;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * "Mot de passe oublié": the admin sets a new password for the phone number
 * a client gave support on WhatsApp.
 */
final class AdminUserPasswordApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    private KernelBrowser $client;

    protected function setUp(): void
    {
        parent::setUp();

        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
    }

    public function testAdminResetsAClientsPasswordFromTheirPhoneNumber(): void
    {
        $adminToken = $this->login($this->createUser('ROLE_ADMIN', 'Admin'));
        $client = $this->createUser('ROLE_CLIENT', 'Sami Client');
        $phone = $client->getPhone();

        // Typed the way the client wrote it on WhatsApp.
        $this->reset($adminToken, '+216 '.substr($phone, 0, 2).' '.substr($phone, 2, 3).' '.substr($phone, 5), 'nouveau2026');

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
        self::assertSame([
            'id' => $client->getId(),
            'name' => 'Sami Client',
            'phone' => $phone,
            'role' => 'CLIENT',
        ], $this->json());

        $this->attemptLogin($phone, 'nouveau2026');
        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $this->attemptLogin($phone, 'password123');
        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    public function testAdminResetsACouriersPasswordToo(): void
    {
        $adminToken = $this->login($this->createUser('ROLE_ADMIN', 'Admin'));
        $courier = $this->createUser('ROLE_LIVREUR', 'Awa Courier');

        $this->reset($adminToken, $courier->getPhone(), 'nouveau2026');

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
        self::assertSame('COURIER', $this->json()['role']);
    }

    public function testUnknownNumberIsA404InFrench(): void
    {
        $adminToken = $this->login($this->createUser('ROLE_ADMIN', 'Admin'));

        $this->reset($adminToken, $this->freePhone(), 'nouveau2026');

        self::assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND);
        self::assertSame('Aucun compte avec ce numéro.', $this->json()['message']);
    }

    public function testAnAdminsPasswordCannotBeResetHere(): void
    {
        $adminToken = $this->login($this->createUser('ROLE_ADMIN', 'Admin'));
        $otherAdmin = $this->createUser('ROLE_ADMIN', 'Other Admin');

        $this->reset($adminToken, $otherAdmin->getPhone(), 'nouveau2026');

        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);

        $this->attemptLogin($otherAdmin->getPhone(), 'password123');
        self::assertResponseStatusCodeSame(Response::HTTP_OK);
    }

    public function testOnlyAdminsCanResetPasswords(): void
    {
        $clientToken = $this->login($this->createUser('ROLE_CLIENT', 'Curious Client'));
        $victim = $this->createUser('ROLE_CLIENT', 'Victim');

        $this->reset($clientToken, $victim->getPhone(), 'nouveau2026');

        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);
    }

    public function testShortPasswordIsRejected(): void
    {
        $adminToken = $this->login($this->createUser('ROLE_ADMIN', 'Admin'));
        $client = $this->createUser('ROLE_CLIENT', 'Sami Client');

        $this->reset($adminToken, $client->getPhone(), '123');

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    private function reset(string $token, string $phone, string $password): void
    {
        $this->client->request(
            'PATCH',
            '/api/admin/users/password',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode(['phone' => $phone, 'password' => $password])
        );
    }

    private function attemptLogin(string $phone, string $password): void
    {
        $this->client->getCookieJar()->clear();
        $this->client->request(
            'POST',
            '/api/auth/login',
            server: ['CONTENT_TYPE' => 'application/json'],
            content: json_encode(['phone' => $phone, 'password' => $password])
        );
    }

    private function login(User $user): string
    {
        $this->attemptLogin($user->getPhone(), 'password123');
        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        return $this->json()['token'];
    }

    /** @return array<string, mixed> */
    private function json(): array
    {
        $data = json_decode($this->client->getResponse()->getContent(), true);
        self::assertIsArray($data);

        return $data;
    }

    private function createUser(string $role, string $name): User
    {
        $user = new User();
        $user->setName($name);
        $user->setPhone($this->freePhone());
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(
            self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123')
        );

        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    /** 8 digits starting 2-9, as PhoneFormat expects, not used yet. */
    private function freePhone(): string
    {
        return (string) random_int(20000000, 99999999);
    }
}
