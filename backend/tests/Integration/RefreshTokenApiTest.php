<?php

namespace App\Tests\Integration;

use App\Entity\RefreshToken;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * The mobile app stays signed in past the JWT's hour by trading its refresh
 * token for a new one (see RefreshTokenService).
 */
final class RefreshTokenApiTest extends WebTestCase
{
    private KernelBrowser $client;
    private EntityManagerInterface $entityManager;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        // Sign-ins are rate-limited per IP; each test starts with a clean slate.
        self::getContainer()->get('cache.rate_limiter')->clear();
    }

    public function testTheAppGetsARefreshTokenButTheAdminDashboardDoesNot(): void
    {
        $user = $this->createUser();

        $mobile = $this->login($user);
        self::assertIsString($mobile['refreshToken']);
        self::assertSame(64, \strlen($mobile['refreshToken']));

        $this->client->request('POST', '/api/auth/login', server: [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_X_CLIENT_PLATFORM' => 'web',
        ], content: json_encode(['phone' => $user->getPhone(), 'password' => 'password123']));
        self::assertResponseIsSuccessful();
        self::assertStringNotContainsString('refreshToken', (string) $this->client->getResponse()->getContent());
    }

    public function testTheAdminDashboardRenewsItsSessionWithCookies(): void
    {
        $user = $this->createUser();
        $web = ['CONTENT_TYPE' => 'application/json', 'HTTP_X_CLIENT_PLATFORM' => 'web'];

        $this->client->request('POST', '/api/auth/login', server: $web, content: json_encode([
            'phone' => $user->getPhone(),
            'password' => 'password123',
        ]));
        self::assertResponseIsSuccessful();
        $refresh = $this->client->getCookieJar()->get('REFRESH', '/api/auth');
        self::assertNotNull($refresh, 'The refresh token comes as a cookie.');
        self::assertTrue($refresh->isHttpOnly());
        $firstRefresh = $refresh->getValue();

        // The session cookie has expired (any invalid JWT does the same).
        $this->client->getCookieJar()->set(new \Symfony\Component\BrowserKit\Cookie('BEARER', 'expired.jwt.value'));

        $this->client->request('POST', '/api/auth/refresh', server: $web);
        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);
        self::assertNotSame($firstRefresh, $this->client->getCookieJar()->get('REFRESH', '/api/auth')->getValue());

        $this->client->request('GET', '/api/auth/me', server: $web);
        self::assertResponseIsSuccessful();

        // Logging out ends it: the cookie is cleared and the token revoked.
        $current = $this->client->getCookieJar()->get('REFRESH', '/api/auth')->getValue();
        $this->client->request('POST', '/api/auth/logout', server: $web);
        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);
        $this->refresh($current);
        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    public function testARefreshTokenBuysANewSessionOnce(): void
    {
        $first = $this->login($this->createUser());

        $second = $this->refresh($first['refreshToken']);
        self::assertResponseIsSuccessful();
        self::assertNotSame($first['refreshToken'], $second['refreshToken']);

        $this->client->request('GET', '/api/auth/me', server: ['HTTP_AUTHORIZATION' => 'Bearer '.$second['token']]);
        self::assertResponseIsSuccessful();

        // Rotated: the old one is spent.
        $this->refresh($first['refreshToken']);
        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
        self::assertSame(
            'Session expirée. Reconnectez-vous.',
            json_decode((string) $this->client->getResponse()->getContent(), true)['message']
        );
    }

    public function testAnExpiredOrUnknownTokenIsRefused(): void
    {
        $user = $this->createUser();
        $session = $this->login($user);
        $this->entityManager->createQuery('UPDATE '.RefreshToken::class.' t SET t.expiresAt = :past WHERE t.user = :user')
            ->setParameter('past', new \DateTimeImmutable('-1 minute'))
            ->setParameter('user', $user)
            ->execute();

        $this->refresh($session['refreshToken']);
        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);

        $this->refresh(str_repeat('a', 64));
        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    public function testSigningOutEndsTheSession(): void
    {
        $session = $this->login($this->createUser());

        $this->client->request('POST', '/api/auth/logout', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'refreshToken' => $session['refreshToken'],
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $this->refresh($session['refreshToken']);
        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    public function testChangingThePasswordSignsOutOtherDevicesOnly(): void
    {
        $user = $this->createUser();
        $phone = $this->login($user);
        $otherPhone = $this->login($user);

        $this->client->request('POST', '/api/auth/change-password', server: [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$phone['token'],
        ], content: json_encode([
            'currentPassword' => 'password123',
            'newPassword' => 'newpassword456',
            'refreshToken' => $phone['refreshToken'],
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $this->refresh($otherPhone['refreshToken']);
        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);

        $this->refresh($phone['refreshToken']);
        self::assertResponseIsSuccessful();
    }

    public function testADeactivatedAccountCannotRenewItsSession(): void
    {
        $user = $this->createUser();
        $session = $this->login($user);

        $user = $this->entityManager->getRepository(User::class)->find($user->getId());
        $user->setActive(false);
        $this->entityManager->flush();

        $this->refresh($session['refreshToken']);
        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    private function createUser(): User
    {
        $user = new User();
        $user->setName('Session Client');
        $user->setPhone((string) random_int(20000000, 99999999));
        $user->setRoles(['ROLE_CLIENT']);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123'));
        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    /**
     * @return array{token: string, refreshToken: string}
     */
    private function login(User $user): array
    {
        $this->client->request('POST', '/api/auth/login', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'phone' => $user->getPhone(),
            'password' => 'password123',
        ]));
        self::assertResponseIsSuccessful();

        return json_decode((string) $this->client->getResponse()->getContent(), true);
    }

    /**
     * @return array{token?: string, refreshToken?: string, message?: string}
     */
    private function refresh(string $refreshToken): array
    {
        $this->client->request('POST', '/api/auth/refresh', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode([
            'refreshToken' => $refreshToken,
        ]));

        return json_decode((string) $this->client->getResponse()->getContent(), true);
    }
}
