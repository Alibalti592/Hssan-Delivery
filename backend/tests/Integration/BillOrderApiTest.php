<?php

namespace App\Tests\Integration;

use App\Entity\BillProvider;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\User;
use App\Enum\BillProviderKind;
use App\Enum\DeliveryStatus;
use Doctrine\ORM\EntityManagerInterface;
use PHPUnit\Framework\Attributes\DataProvider;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\File\UploadedFile;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * Factures: bill providers (admin-managed, client-visible when active),
 * bill and mandat orders, and the private bill photo.
 */
final class BillOrderApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;
    private KernelBrowser $client;
    private User $customer;
    private string $customerToken;
    private DeliveryZone $zone;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        $this->customer = $this->createUser('ROLE_CLIENT');
        $this->customerToken = $this->authenticate($this->customer);

        $this->zone = (new DeliveryZone())->setName('Bill Zone '.random_int(1000000, 999999999))->setFee('7.000');
        $this->entityManager->persist($this->zone);
        $this->entityManager->flush();
    }

    public function testTheClientSeesOnlyVisibleProvidersInTheirOrder(): void
    {
        $second = $this->createProvider(BillProviderKind::BILL, position: 900);
        $first = $this->createProvider(BillProviderKind::TRANSFER, position: 899);
        $hidden = $this->createProvider(BillProviderKind::BILL, position: 898, active: false);

        $this->client->request('GET', '/api/bill-providers', server: $this->headers($this->customerToken));

        self::assertResponseIsSuccessful();
        $providers = json_decode($this->client->getResponse()->getContent(), true);
        $ids = array_column($providers, 'id');

        self::assertNotContains($hidden->getId(), $ids);
        self::assertLessThan(array_search($second->getId(), $ids, true), array_search($first->getId(), $ids, true));
        self::assertSame(
            ['id' => $first->getId(), 'name' => $first->getName(), 'kind' => 'TRANSFER', 'logoUrl' => null, 'isActive' => true, 'position' => 899],
            $providers[array_search($first->getId(), $ids, true)]
        );
    }

    public function testTheSeededProvidersAreThere(): void
    {
        $this->client->request('GET', '/api/bill-providers', server: $this->headers($this->customerToken));

        $names = array_column(json_decode($this->client->getResponse()->getContent(), true), 'name');

        foreach (['STEG', 'SONEDE', 'Tunisie Telecom', 'Topnet', 'IZI – Banque Zitouna', 'Wafa Cash'] as $seeded) {
            self::assertContains($seeded, $names);
        }
    }

    public function testABillOrderChargesTheAmountPlusTheZoneFee(): void
    {
        $provider = $this->createProvider(BillProviderKind::BILL);

        $order = $this->placeBillOrder([
            'providerId' => $provider->getId(),
            'reference' => ' 1234567890 ',
            'amount' => '85.5',
            // Ignored for a bill: nobody else receives anything.
            'recipientName' => 'Someone',
            'recipientPhone' => '22123456',
            'note' => 'Sonnez deux fois',
        ]);

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        self::assertSame('BILL', $order['deliveryType']);
        self::assertNull($order['restaurantId']);
        self::assertSame('7.000', $order['deliveryFee']);
        self::assertSame('92.500', $order['totalAmount']);
        self::assertSame('Rue de Marseille, Tunis', $order['pickupAddress']);
        self::assertSame('Rue de Marseille, Tunis', $order['deliveryAddress']);
        self::assertNull($order['recipientName']);
        self::assertNull($order['recipientPhone']);
        self::assertSame('PENDING', $order['deliveryStatus']);
        self::assertSame([
            'providerId' => $provider->getId(),
            'providerName' => $provider->getName(),
            'providerKind' => 'BILL',
            'providerLogoUrl' => null,
            'reference' => '1234567890',
            'amount' => '85.500',
            'photoUrl' => null,
        ], $order['bill']);

        // It's in the client's order history too.
        $this->client->request('GET', '/api/orders', server: $this->headers($this->customerToken));
        $listed = json_decode($this->client->getResponse()->getContent(), true)['items'][0];
        self::assertSame($order['id'], $listed['id']);
        self::assertSame('1234567890', $listed['bill']['reference']);
    }

    public function testAMandatNeedsItsRecipientAndHasNoReference(): void
    {
        $provider = $this->createProvider(BillProviderKind::TRANSFER);

        $order = $this->placeBillOrder([
            'providerId' => $provider->getId(),
            'reference' => 'ignored',
            'amount' => '300',
            'recipientName' => 'Mohamed Ben Ali',
            'recipientPhone' => '+216 98 765 432',
        ]);

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        self::assertSame('307.000', $order['totalAmount']);
        self::assertSame('Mohamed Ben Ali', $order['recipientName']);
        self::assertSame('+216 98 765 432', $order['recipientPhone']);
        self::assertSame('TRANSFER', $order['bill']['providerKind']);
        self::assertNull($order['bill']['reference']);
    }

    /**
     * @param array<string, mixed> $body
     */
    #[DataProvider('invalidOrders')]
    public function testInvalidBillOrdersAreRejected(BillProviderKind $kind, array $body, string $field): void
    {
        $provider = $this->createProvider($kind);

        $this->placeBillOrder(['providerId' => $provider->getId()] + $body);

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
        $errors = json_decode($this->client->getResponse()->getContent(), true)['errors'];
        self::assertContains($field, array_column($errors, 'field'));
    }

    public static function invalidOrders(): iterable
    {
        yield 'bill without reference' => [BillProviderKind::BILL, ['reference' => '  ', 'amount' => '10'], 'reference'];
        yield 'mandat without recipient' => [BillProviderKind::TRANSFER, ['amount' => '10', 'recipientPhone' => '22123456'], 'recipientName'];
        yield 'mandat without phone' => [BillProviderKind::TRANSFER, ['amount' => '10', 'recipientName' => 'Ali'], 'recipientPhone'];
        yield 'mandat with a bad phone' => [BillProviderKind::TRANSFER, ['amount' => '10', 'recipientName' => 'Ali', 'recipientPhone' => '123'], 'recipientPhone'];
        yield 'zero amount' => [BillProviderKind::BILL, ['reference' => 'R1', 'amount' => '0'], 'amount'];
        yield 'too much cash' => [BillProviderKind::BILL, ['reference' => 'R1', 'amount' => '2000.001'], 'amount'];
        yield 'not a number' => [BillProviderKind::BILL, ['reference' => 'R1', 'amount' => '12,5'], 'amount'];
    }

    public function testAHiddenProviderCannotBeOrdered(): void
    {
        $provider = $this->createProvider(BillProviderKind::BILL, active: false);

        $this->placeBillOrder(['providerId' => $provider->getId(), 'reference' => 'R1', 'amount' => '10']);

        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
    }

    public function testTheBillPhotoIsOnlyShownToTheClientTheirCourierAndAdmins(): void
    {
        $order = $this->placeBillOrder([
            'providerId' => $this->createProvider(BillProviderKind::BILL)->getId(),
            'reference' => 'R1',
            'amount' => '40',
        ]);

        $this->client->request(
            'POST',
            '/api/orders/'.$order['id'].'/bill-photo',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$this->customerToken],
            files: ['photo' => $this->pngUpload()]
        );

        self::assertResponseIsSuccessful();
        $photoUrl = json_decode($this->client->getResponse()->getContent(), true)['bill']['photoUrl'];
        self::assertSame('/api/orders/'.$order['id'].'/bill-photo', $photoUrl);

        // Stored outside the public uploads.
        $filename = $this->findOrder($order['id'])->getBillPhotoFilename();
        $projectDir = self::getContainer()->getParameter('kernel.project_dir');
        self::assertFileExists($projectDir.'/var/storage/private/bills/'.$filename);
        self::assertFileDoesNotExist($projectDir.'/public/uploads/bills/'.$filename);

        $courier = $this->createUser('ROLE_LIVREUR');
        $courierToken = $this->authenticate($courier);

        self::assertSame(Response::HTTP_OK, $this->fetchPhoto($photoUrl, $this->customerToken));
        self::assertSame(Response::HTTP_OK, $this->fetchPhoto($photoUrl, $this->authenticate($this->createUser('ROLE_ADMIN'))));
        self::assertSame(Response::HTTP_NOT_FOUND, $this->fetchPhoto($photoUrl, $this->authenticate($this->createUser('ROLE_CLIENT'))));
        self::assertSame(Response::HTTP_NOT_FOUND, $this->fetchPhoto($photoUrl, $courierToken));

        $this->assignCourier($order['id'], $courier, DeliveryStatus::ASSIGNED);

        self::assertSame(Response::HTTP_OK, $this->fetchPhoto($photoUrl, $courierToken));

        // The courier's job carries the bill details and the photo link.
        $this->client->request('GET', '/api/deliveries/mine', server: $this->headers($courierToken));
        $job = json_decode($this->client->getResponse()->getContent(), true)['items'][0];
        self::assertSame('R1', $job['order']['bill']['reference']);
        self::assertSame('40.000', $job['order']['bill']['amount']);
        self::assertSame($photoUrl, $job['order']['bill']['photoUrl']);

        @unlink($projectDir.'/var/storage/private/bills/'.$filename);
    }

    public function testTheBillPhotoCannotChangeOnceTheCourierHasAccepted(): void
    {
        $order = $this->placeBillOrder([
            'providerId' => $this->createProvider(BillProviderKind::BILL)->getId(),
            'reference' => 'R1',
            'amount' => '40',
        ]);
        $this->assignCourier($order['id'], $this->createUser('ROLE_LIVREUR'), DeliveryStatus::ACCEPTED);

        $this->client->request(
            'POST',
            '/api/orders/'.$order['id'].'/bill-photo',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$this->customerToken],
            files: ['photo' => $this->pngUpload()]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_BAD_REQUEST);
    }

    public function testOnlyTheOrdersOwnerCanAttachAPhoto(): void
    {
        $order = $this->placeBillOrder([
            'providerId' => $this->createProvider(BillProviderKind::BILL)->getId(),
            'reference' => 'R1',
            'amount' => '40',
        ]);

        $this->client->request(
            'POST',
            '/api/orders/'.$order['id'].'/bill-photo',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$this->authenticate($this->createUser('ROLE_CLIENT'))],
            files: ['photo' => $this->pngUpload()]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND);
    }

    public function testAnAdminManagesProviders(): void
    {
        $headers = $this->headers($this->authenticate($this->createUser('ROLE_ADMIN')));
        $name = 'Ooredoo '.random_int(1000000, 999999999);

        $this->client->request('POST', '/api/admin/bill-providers', server: $headers, content: json_encode([
            'name' => '  '.$name.' ',
            'kind' => 'BILL',
            'position' => 7,
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        $created = json_decode($this->client->getResponse()->getContent(), true);
        self::assertSame($name, $created['name']);
        self::assertTrue($created['isActive']);

        // Names are unique.
        $this->client->request('POST', '/api/admin/bill-providers', server: $headers, content: json_encode([
            'name' => $name,
            'kind' => 'TRANSFER',
            'position' => 1,
        ]));
        self::assertResponseStatusCodeSame(Response::HTTP_CONFLICT);

        $this->client->request('PUT', '/api/admin/bill-providers/'.$created['id'], server: $headers, content: json_encode([
            'name' => $name,
            'kind' => 'TRANSFER',
            'position' => 3,
        ]));
        self::assertResponseIsSuccessful();
        self::assertSame('TRANSFER', json_decode($this->client->getResponse()->getContent(), true)['kind']);

        $this->client->request('PATCH', '/api/admin/bill-providers/'.$created['id'].'/active', server: $headers, content: json_encode(['isActive' => false]));
        self::assertFalse(json_decode($this->client->getResponse()->getContent(), true)['isActive']);

        $this->client->request(
            'POST',
            '/api/admin/bill-providers/'.$created['id'].'/logo',
            server: ['HTTP_AUTHORIZATION' => $headers['HTTP_AUTHORIZATION']],
            files: ['logo' => $this->pngUpload()]
        );
        self::assertResponseIsSuccessful();
        $logoUrl = json_decode($this->client->getResponse()->getContent(), true)['logoUrl'];
        self::assertStringStartsWith('/uploads/bill-providers/', $logoUrl);

        $this->client->request('DELETE', '/api/admin/bill-providers/'.$created['id'].'/logo', server: $headers);
        self::assertNull(json_decode($this->client->getResponse()->getContent(), true)['logoUrl']);

        // Hidden providers still show up for the admin.
        $this->client->request('GET', '/api/admin/bill-providers', server: $headers);
        self::assertContains($created['id'], array_column(json_decode($this->client->getResponse()->getContent(), true), 'id'));
    }

    public function testClientsCannotManageProviders(): void
    {
        $this->client->request('POST', '/api/admin/bill-providers', server: $this->headers($this->customerToken), content: json_encode([
            'name' => 'Nope',
            'kind' => 'BILL',
            'position' => 1,
        ]));

        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);
    }

    /**
     * @param array<string, mixed> $body
     *
     * @return array<string, mixed>
     */
    private function placeBillOrder(array $body): array
    {
        $this->client->request('POST', '/api/orders/bills', server: $this->headers($this->customerToken), content: json_encode($body + [
            'address' => 'Rue de Marseille, Tunis',
            'deliveryZoneId' => $this->zone->getId(),
        ]));

        return json_decode($this->client->getResponse()->getContent(), true);
    }

    private function fetchPhoto(string $url, string $token): int
    {
        $this->client->request('GET', $url, server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]);

        return $this->client->getResponse()->getStatusCode();
    }

    private function assignCourier(int $orderId, User $courier, DeliveryStatus $status): void
    {
        $delivery = $this->findOrder($orderId)->getDelivery();
        $courier = $this->entityManager->getRepository(User::class)->find($courier->getId());
        $delivery->setCourier($courier);
        $delivery->setStatus($status);
        $this->entityManager->flush();
    }

    private function findOrder(int $id): Order
    {
        $this->entityManager->clear();

        return $this->entityManager->getRepository(Order::class)->find($id);
    }

    private function createProvider(BillProviderKind $kind, int $position = 500, bool $active = true): BillProvider
    {
        $provider = (new BillProvider())
            ->setName('Provider '.random_int(1000000, 999999999))
            ->setKind($kind)
            ->setPosition($position)
            ->setIsActive($active);

        $this->entityManager->persist($provider);
        $this->entityManager->flush();

        return $provider;
    }

    private function pngUpload(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'bill').'.png';
        file_put_contents($path, base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));

        return new UploadedFile($path, 'bill.png', 'image/png', null, true);
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
