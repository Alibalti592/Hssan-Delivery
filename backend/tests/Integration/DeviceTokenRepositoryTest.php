<?php

namespace App\Tests\Integration;

use App\Entity\DeviceToken;
use App\Entity\User;
use App\Repository\DeviceTokenRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * Covers DeviceTokenRepository::deleteByTokens — the bulk-prune query
 * PushNotificationService::notifyUser runs after every multicast send to
 * drop tokens FCM reported as unknown/invalid, so they stop being retried
 * on every future notification.
 */
final class DeviceTokenRepositoryTest extends KernelTestCase
{
    private EntityManagerInterface $entityManager;
    private DeviceTokenRepository $repository;

    protected function setUp(): void
    {
        parent::setUp();

        self::bootKernel();

        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        $this->repository = self::getContainer()->get(DeviceTokenRepository::class);
    }

    public function testDeletesOnlyTheGivenTokens(): void
    {
        $user = $this->createTestUser();
        $stale = $this->createDeviceToken($user, $this->uniqueToken());
        $kept = $this->createDeviceToken($user, $this->uniqueToken());

        $this->repository->deleteByTokens([$stale->getToken()]);

        $this->entityManager->clear();

        self::assertNull(
            $this->entityManager->getRepository(DeviceToken::class)->find($stale->getId())
        );
        self::assertNotNull(
            $this->entityManager->getRepository(DeviceToken::class)->find($kept->getId())
        );
    }

    public function testEmptyListIsANoop(): void
    {
        $user = $this->createTestUser();
        $token = $this->createDeviceToken($user, $this->uniqueToken());

        $this->repository->deleteByTokens([]);

        $this->entityManager->clear();

        self::assertNotNull(
            $this->entityManager->getRepository(DeviceToken::class)->find($token->getId())
        );
    }

    private function createTestUser(): User
    {
        $user = new User();

        $user->setName('Test Client');
        $user->setPhone($this->uniquePhone());
        $user->setRoles(['ROLE_CLIENT']);
        $user->setVerifiedAt(new \DateTimeImmutable());

        $passwordHasher = self::getContainer()->get(UserPasswordHasherInterface::class);

        $user->setPassword($passwordHasher->hashPassword($user, 'password123'));

        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return $user;
    }

    private function createDeviceToken(User $user, string $token): DeviceToken
    {
        $deviceToken = new DeviceToken();

        $deviceToken->setUser($user);
        $deviceToken->setToken($token);

        $this->entityManager->persist($deviceToken);
        $this->entityManager->flush();

        return $deviceToken;
    }

    private function uniquePhone(): string
    {
        return (string) random_int(20000000, 99999999);
    }

    private function uniqueToken(): string
    {
        return 'fcm-token-'.bin2hex(random_bytes(16));
    }
}
