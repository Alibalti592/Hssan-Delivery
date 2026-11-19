<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\Delivery;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\OrderItem;
use App\Entity\Product;
use App\Entity\Promotion;
use App\Entity\PushCampaign;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\DiscountType;
use App\Enum\OrderStatus;
use App\Tests\Support\QueryCounter;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * Lists cost the same number of queries for 2 rows as for 6: none goes
 * back to loading each row's restaurant, customer or sender one by one
 * (N+1). The page is always filled with rows made here, newest first.
 */
final class QueryCountTest extends WebTestCase
{
    private KernelBrowser $client;
    private EntityManagerInterface $entityManager;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        // One kernel for the whole test: the entity manager cleared before
        // each request is the one the request uses.
        $this->client->disableReboot();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
    }

    public function testAdminPromotionsLoadTheirRestaurantsInTheSameQuery(): void
    {
        for ($i = 0; $i < 6; ++$i) {
            $this->entityManager->persist(
                (new Promotion())
                    ->setTitle("N+1 promo {$i}")
                    ->setDiscountType(DiscountType::PERCENTAGE)
                    ->setDiscountValue('10.000')
                    ->setStartAt(new \DateTimeImmutable('-1 hour'))
                    ->setIsActive(true)
                    ->setRestaurant($this->restaurant("N+1 promo place {$i}"))
            );
        }
        $this->entityManager->flush();

        $this->assertFlat('/api/admin/promotions', $this->adminToken());
    }

    public function testAdminNotificationsLoadTheirPromotionAndSenderInTheSameQuery(): void
    {
        $token = $this->adminToken();
        // 8 campaigns, each with its own promotion and sender, the newest of
        // all: one query per row would be at least 8 more than the list's few.
        for ($i = 0; $i < 8; ++$i) {
            $promotion = (new Promotion())
                ->setTitle("N+1 campaign promo {$i}")
                ->setDiscountType(DiscountType::PERCENTAGE)
                ->setDiscountValue('10.000')
                ->setStartAt(new \DateTimeImmutable('-1 hour'))
                ->setIsActive(true);
            $this->entityManager->persist($promotion);
            $this->entityManager->persist(
                (new PushCampaign())
                    ->setTitle("N+1 campaign {$i}")
                    ->setBody('Texte')
                    ->setPromotion($promotion)
                    ->setSentBy($this->user('ROLE_ADMIN'))
                    ->setRecipients(1)
            );
        }
        $this->entityManager->flush();

        // The admin, the campaigns with their promotion and sender, the
        // phone count: the list always holds the latest 30, so no page size
        // to compare; one query per campaign would be far above this.
        self::assertLessThanOrEqual(6, $this->queries('/api/admin/notifications', $token));
    }

    public function testOrderAndDeliveryListsDoNotLoadRowsOneByOne(): void
    {
        $customer = $this->user('ROLE_CLIENT');
        $restaurant = $this->restaurant('N+1 orders place');
        $category = (new Category())->setName('Plats')->setRestaurant($restaurant);
        $product = (new Product())->setName('Plat')->setPrice('10.000')->setIsAvailable(true)
            ->setRestaurant($restaurant)->setCategory($category);
        $zone = (new DeliveryZone())->setName('N+1 zone '.random_int(1000000, 999999999))->setFee('3.000');
        $this->entityManager->persist($category);
        $this->entityManager->persist($product);
        $this->entityManager->persist($zone);
        for ($i = 0; $i < 6; ++$i) {
            $order = (new Order())
                ->setUser($customer)
                ->setRestaurant($restaurant)
                ->setDeliveryAddress('Rue de Marseille')
                ->setDeliveryZone($zone)
                ->setDeliveryFee('3.000')
                ->setTotalAmount('13.000')
                ->setStatus(OrderStatus::PENDING);
            $order->addItem((new OrderItem())->setProduct($product)->setQuantity(1)->setUnitPrice('10.000'));
            $delivery = (new Delivery())->setOrder($order)->setStatus(DeliveryStatus::PENDING);
            $order->setDelivery($delivery);
            $this->entityManager->persist($order);
            $this->entityManager->persist($delivery);
        }
        $this->entityManager->flush();

        $admin = $this->adminToken();
        $this->assertFlat('/api/admin/orders', $admin);
        $this->assertFlat('/api/admin/deliveries', $admin);
        $this->assertFlat('/api/orders', $this->login($customer));
    }

    /** The same queries for a page of 2 as for a page of 6. */
    private function assertFlat(string $url, string $token): void
    {
        $two = $this->queries($url.'?limit=2', $token);
        $six = $this->queries($url.'?limit=6', $token);

        self::assertSame($two, $six, "{$url}: {$two} queries for 2 rows, {$six} for 6");
    }

    /** How many SQL statements one request for [url] runs. */
    private function queries(string $url, string $token): int
    {
        // Nothing left over from setting up or an earlier request: every
        // row is loaded by the request itself, as in production.
        $this->entityManager->clear();
        QueryCounter::reset();

        $this->client->request('GET', $url, server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token]);
        self::assertResponseIsSuccessful();

        return QueryCounter::count();
    }

    private function restaurant(string $name): Restaurant
    {
        $restaurant = (new Restaurant())->setName($name.' '.random_int(1000, 999999))->setIsAvailable(true);
        $this->entityManager->persist($restaurant);

        return $restaurant;
    }

    private function adminToken(): string
    {
        return $this->login($this->user('ROLE_ADMIN'));
    }

    private function user(string $role): User
    {
        $user = new User();
        $user->setName("N+1 {$role}");
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
