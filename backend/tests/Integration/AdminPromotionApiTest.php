<?php

namespace App\Tests\Integration;

use App\Entity\Promotion;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\DiscountType;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\File\UploadedFile;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

final class AdminPromotionApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;

    public function testAdminCanCreatePromotion(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'POST',
            '/api/admin/promotions',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'title' => 'Summer Discount',
                'description' => '10% off this week',
                'discountType' => 'PERCENTAGE',
                'discountValue' => '10.000',
                'promoCode' => 'SUMMER10',
                'startAt' => (new \DateTimeImmutable('-1 day'))->format(\DateTimeInterface::ATOM),
                'endAt' => (new \DateTimeImmutable('+1 week'))->format(\DateTimeInterface::ATOM),
                'isActive' => true,
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertIsArray($response);
        self::assertArrayHasKey('id', $response);
        self::assertSame('Summer Discount', $response['title']);
        self::assertSame('PERCENTAGE', $response['discountType']);
        self::assertSame('10.000', $response['discountValue']);
        self::assertSame('SUMMER10', $response['promoCode']);
        self::assertTrue($response['isActive']);
        self::assertNull($response['photoUrl']);
        self::assertNull($response['restaurantId']);

        $this->entityManager->clear();

        $promotion = $this->entityManager->getRepository(Promotion::class)->find($response['id']);

        self::assertNotNull($promotion);
        self::assertSame('Summer Discount', $promotion->getTitle());
        self::assertSame(DiscountType::PERCENTAGE, $promotion->getDiscountType());
    }

    public function testAdminCanCreatePromotionWithRestaurant(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $restaurant = (new Restaurant())
            ->setName('Promo Restaurant')
            ->setDescription(null)
            ->setIsAvailable(true);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'POST',
            '/api/admin/promotions',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'title' => 'Restaurant Promo',
                'discountType' => 'FIXED_AMOUNT',
                'discountValue' => '5.000',
                'startAt' => (new \DateTimeImmutable('-1 day'))->format(\DateTimeInterface::ATOM),
                'endAt' => (new \DateTimeImmutable('+1 week'))->format(\DateTimeInterface::ATOM),
                'isActive' => true,
                'restaurantId' => $restaurant->getId(),
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertSame($restaurant->getId(), $response['restaurantId']);
        self::assertSame('Promo Restaurant', $response['restaurantName']);
    }

    public function testCreatingPromotionWithUnknownRestaurantIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'POST',
            '/api/admin/promotions',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'title' => 'Bad Restaurant Promo',
                'discountType' => 'PERCENTAGE',
                'discountValue' => '10.000',
                'startAt' => (new \DateTimeImmutable('-1 day'))->format(\DateTimeInterface::ATOM),
                'endAt' => (new \DateTimeImmutable('+1 week'))->format(\DateTimeInterface::ATOM),
                'isActive' => true,
                'restaurantId' => 999999,
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
    }

    public function testEndDateBeforeStartDateIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'POST',
            '/api/admin/promotions',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'title' => 'Backwards Promo',
                'discountType' => 'PERCENTAGE',
                'discountValue' => '10.000',
                'startAt' => (new \DateTimeImmutable('+1 week'))->format(\DateTimeInterface::ATOM),
                'endAt' => (new \DateTimeImmutable('-1 day'))->format(\DateTimeInterface::ATOM),
                'isActive' => true,
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertSame('End date must be after the start date.', $response['message']);
    }

    public function testPercentageDiscountOver100IsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'POST',
            '/api/admin/promotions',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'title' => 'Too Generous Promo',
                'discountType' => 'PERCENTAGE',
                'discountValue' => '150.000',
                'startAt' => (new \DateTimeImmutable('-1 day'))->format(\DateTimeInterface::ATOM),
                'endAt' => (new \DateTimeImmutable('+1 week'))->format(\DateTimeInterface::ATOM),
                'isActive' => true,
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertSame('A percentage discount cannot exceed 100.', $response['message']);
    }

    public function testInvalidPromotionDataIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'POST',
            '/api/admin/promotions',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'title' => '',
                'discountType' => 'INVALID_TYPE',
                'discountValue' => 'not-a-number',
                'isActive' => true,
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertSame('Validation failed.', $response['message']);
        self::assertArrayHasKey('errors', $response);
    }

    public function testPromotionDiscountValueWithTooManyIntegerDigitsIsRejected(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $adminToken = $this->authenticateClient($client, $admin);

        // The `discountValue` column is decimal(10,3) — 7 integer digits
        // max. This must be rejected by validation (422), not reach
        // flush() and blow up as a raw DBAL out-of-range exception (500).
        $client->request(
            'POST',
            '/api/admin/promotions',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'title' => 'Absurd Discount',
                'discountType' => 'FIXED_AMOUNT',
                'discountValue' => '99999999.999',
                'startAt' => (new \DateTimeImmutable('-1 day'))->format(\DateTimeInterface::ATOM),
                'endAt' => (new \DateTimeImmutable('+1 week'))->format(\DateTimeInterface::ATOM),
                'isActive' => true,
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    public function testNonAdminCannotCreatePromotion(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $clientUser = $this->createTestUser('ROLE_USER', 'Test Client');

        $token = $this->authenticateClient($client, $clientUser);

        $client->request(
            'POST',
            '/api/admin/promotions',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: json_encode([
                'title' => 'Unauthorized Promo',
                'discountType' => 'PERCENTAGE',
                'discountValue' => '10.000',
                'startAt' => (new \DateTimeImmutable('-1 day'))->format(\DateTimeInterface::ATOM),
                'endAt' => (new \DateTimeImmutable('+1 week'))->format(\DateTimeInterface::ATOM),
                'isActive' => true,
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);
    }

    public function testAdminCanListPromotions(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $promotion = $this->createPromotion('List Promo', true, new \DateTimeImmutable('-1 day'), new \DateTimeImmutable('+1 week'));

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'GET',
            '/api/admin/promotions',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode($client->getResponse()->getContent(), true);

        $ids = array_column($response['items'], 'id');

        self::assertContains($promotion->getId(), $ids);
    }

    public function testNonAdminCannotListPromotions(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_USER', 'Test Client');

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/admin/promotions',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);
    }

    public function testAdminCanUpdatePromotion(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $promotion = $this->createPromotion('Old Title', true, new \DateTimeImmutable('-1 day'), new \DateTimeImmutable('+1 week'));

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'PUT',
            '/api/admin/promotions/'.$promotion->getId(),
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode([
                'title' => 'New Title',
                'discountType' => 'FIXED_AMOUNT',
                'discountValue' => '3.000',
                'startAt' => (new \DateTimeImmutable('-1 day'))->format(\DateTimeInterface::ATOM),
                'endAt' => (new \DateTimeImmutable('+1 week'))->format(\DateTimeInterface::ATOM),
                'isActive' => false,
            ])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertSame('New Title', $response['title']);
        self::assertSame('FIXED_AMOUNT', $response['discountType']);
        self::assertFalse($response['isActive']);
    }

    public function testAdminCanToggleActive(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $promotion = $this->createPromotion('Toggle Promo', true, new \DateTimeImmutable('-1 day'), new \DateTimeImmutable('+1 week'));

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'PATCH',
            '/api/admin/promotions/'.$promotion->getId().'/active',
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$adminToken,
            ],
            content: json_encode(['isActive' => false])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertFalse($response['isActive']);
    }

    public function testAdminCanDeletePromotion(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $promotion = $this->createPromotion('Delete Promo', true, new \DateTimeImmutable('-1 day'), new \DateTimeImmutable('+1 week'));

        $promotionId = $promotion->getId();

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'DELETE',
            '/api/admin/promotions/'.$promotionId,
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $this->entityManager->clear();

        self::assertNull($this->entityManager->getRepository(Promotion::class)->find($promotionId));
    }

    public function testAdminCanUploadAndRemovePromotionPhoto(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $admin = $this->createTestUser('ROLE_ADMIN', 'Test Admin');

        $promotion = $this->createPromotion('Photo Promo', true, new \DateTimeImmutable('-1 day'), new \DateTimeImmutable('+1 week'));

        $adminToken = $this->authenticateClient($client, $admin);

        $client->request(
            'POST',
            '/api/admin/promotions/'.$promotion->getId().'/photo',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken],
            files: ['photo' => $this->createPngUploadedFile()]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertIsString($response['photoUrl']);
        self::assertStringStartsWith('/uploads/promotions/', $response['photoUrl']);

        $client->request(
            'DELETE',
            '/api/admin/promotions/'.$promotion->getId().'/photo',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$adminToken]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertNull($response['photoUrl']);
    }

    public function testPublicEndpointOnlyReturnsCurrentlyValidPromotions(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_USER', 'Public Client');

        $valid = $this->createPromotion('Valid Promo', true, new \DateTimeImmutable('-1 day'), new \DateTimeImmutable('+1 week'));
        $expired = $this->createPromotion('Expired Promo', true, new \DateTimeImmutable('-2 weeks'), new \DateTimeImmutable('-1 week'));
        $notStarted = $this->createPromotion('Future Promo', true, new \DateTimeImmutable('+1 week'), new \DateTimeImmutable('+2 weeks'));
        $inactive = $this->createPromotion('Inactive Promo', false, new \DateTimeImmutable('-1 day'), new \DateTimeImmutable('+1 week'));

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/promotions',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode($client->getResponse()->getContent(), true);

        $ids = array_column($response, 'id');

        self::assertContains($valid->getId(), $ids);
        self::assertNotContains($expired->getId(), $ids);
        self::assertNotContains($notStarted->getId(), $ids);
        self::assertNotContains($inactive->getId(), $ids);
    }

    public function testPublicShowReturns404ForExpiredPromotion(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_USER', 'Public Client');

        $expired = $this->createPromotion('Expired Show Promo', true, new \DateTimeImmutable('-2 weeks'), new \DateTimeImmutable('-1 week'));

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/promotions/'.$expired->getId(),
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND);
    }

    public function testPublicShowReturnsValidPromotion(): void
    {
        $client = static::createClient();

        $this->entityManager = self::getContainer()
            ->get(EntityManagerInterface::class);

        $user = $this->createTestUser('ROLE_USER', 'Public Client');

        $valid = $this->createPromotion('Valid Show Promo', true, new \DateTimeImmutable('-1 day'), new \DateTimeImmutable('+1 week'));

        $token = $this->authenticateClient($client, $user);

        $client->request(
            'GET',
            '/api/promotions/'.$valid->getId(),
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]
        );

        self::assertResponseIsSuccessful();

        $response = json_decode($client->getResponse()->getContent(), true);

        self::assertSame($valid->getId(), $response['id']);
        self::assertSame('Valid Show Promo', $response['title']);
    }

    private function createPromotion(string $title, bool $isActive, \DateTimeImmutable $startAt, \DateTimeImmutable $endAt): Promotion
    {
        $promotion = (new Promotion())
            ->setTitle($title)
            ->setDescription(null)
            ->setDiscountType(DiscountType::PERCENTAGE)
            ->setDiscountValue('10.000')
            ->setPromoCode(null)
            ->setStartAt($startAt)
            ->setEndAt($endAt)
            ->setIsActive($isActive);

        $this->entityManager->persist($promotion);
        $this->entityManager->flush();

        return $promotion;
    }

    private function createPngUploadedFile(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'photo').'.png';

        file_put_contents(
            $path,
            base64_decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='
            )
        );

        return new UploadedFile($path, 'photo.png', 'image/png', null, true);
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
