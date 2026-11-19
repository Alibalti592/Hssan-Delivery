<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\Delivery;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\OrderItem;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Enum\OrderStatus;
use App\Event\DeliveryStatusChangedEvent;
use App\Tests\Support\QueryCounter;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Contracts\EventDispatcher\EventDispatcherInterface;

/**
 * "Les plus commandés" / "Restaurants populaires": real counts of delivered
 * orders, recent ones only, and nothing below three orders.
 */
final class PopularApiTest extends WebTestCase
{
    private KernelBrowser $client;
    private EntityManagerInterface $entityManager;
    private User $user;
    private string $token;
    private string $tag;
    private DeliveryZone $zone;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        $this->tag = 'Popular-'.random_int(100000, 999999);

        // The test database keeps earlier runs' rows: close their
        // restaurants, so they don't crowd this run's out of the top.
        $this->entityManager->createQuery(
            "UPDATE App\Entity\Restaurant r SET r.isAvailable = false WHERE r.name LIKE 'Popular-%'"
        )->execute();

        // Orders are set up directly here, not delivered: the ranking an
        // earlier test cached would hide them.
        self::getContainer()->get('cache.popular')->clear();

        $this->zone = (new DeliveryZone())->setName("Zone {$this->tag}")->setFee('3.000');
        $this->entityManager->persist($this->zone);
        $this->user = $this->createUser();
        $this->token = $this->login($this->user);
    }

    public function testCountsDeliveredOrdersOfTheLastThirtyDays(): void
    {
        [$pizzeria, $margherita, $calzone] = $this->restaurantWith('Pizzeria', ['Margherita', 'Calzone']);
        [$snack, $sandwich] = $this->restaurantWith('Snack', ['Sandwich']);
        [$cafe, $crepe] = $this->restaurantWith('Café', ['Crêpe']);
        [$closed, $closedDish] = $this->restaurantWith('Fermé', ['Plat'], open: false);

        // Pizzeria: 5 delivered orders with a margherita (one with two),
        // 2 with a calzone.
        for ($i = 0; $i < 5; ++$i) {
            $this->order($pizzeria, [$margherita, ...(0 === $i ? [$margherita] : []), ...($i < 2 ? [$calzone] : [])]);
        }
        // Snack: 3 delivered, plus one too old to count.
        for ($i = 0; $i < 3; ++$i) {
            $this->order($snack, [$sandwich]);
        }
        $old = $this->order($snack, [$sandwich]);
        // Café: 2 delivered, and cancelled ones that don't count.
        for ($i = 0; $i < 2; ++$i) {
            $this->order($cafe, [$crepe]);
        }
        for ($i = 0; $i < 4; ++$i) {
            $this->order($cafe, [$crepe], OrderStatus::CANCELLED);
        }
        // Closed: plenty of orders, but nothing to order there now.
        for ($i = 0; $i < 4; ++$i) {
            $this->order($closed, [$closedDish]);
        }
        $this->entityManager->flush();
        $this->entityManager->createQuery('UPDATE App\Entity\Order o SET o.createdAt = :then WHERE o.id = :id')
            ->setParameter('then', new \DateTimeImmutable('-40 days'))
            ->setParameter('id', $old->getId())
            ->execute();

        $result = $this->popular();
        $mine = fn (array $rows, string $key) => array_values(array_filter(
            $rows,
            fn (array $row) => str_starts_with($key === 'name' ? $row['name'] : $row['restaurant']['name'], $this->tag)
        ));

        $restaurants = $mine($result['restaurants'], 'name');
        self::assertSame(["{$this->tag} Pizzeria", "{$this->tag} Snack"], array_column($restaurants, 'name'));
        self::assertSame([5, 3], array_column($restaurants, 'orderCount'));

        $dishes = $mine($result['dishes'], 'restaurant');
        self::assertSame(['Margherita', 'Sandwich'], array_column($dishes, 'name'));
        self::assertSame([5, 3], array_column($dishes, 'orderCount'));
        self::assertSame("{$this->tag} Pizzeria", $dishes[0]['restaurant']['name']);
        self::assertSame(30, $result['windowDays']);
    }

    public function testTheRankingIsCachedButAClosedRestaurantLeavesAtOnce(): void
    {
        // One kernel, so its cache lasts from one request to the next.
        $this->client->disableReboot();
        [$restaurant, $dish] = $this->restaurantWith('Cached', ['Plat du cache']);
        for ($i = 0; $i < 3; ++$i) {
            $this->order($restaurant, [$dish]);
        }
        self::assertContains("{$this->tag} Cached", array_column($this->popular()['restaurants'], 'name'));

        // Asked again: the ranking comes from the cache, no counting query.
        self::assertSame([], $this->rankingQueries(fn () => $this->popular()));

        // Closed meanwhile: gone at once, though the ranking is cached.
        $this->entityManager->find(Restaurant::class, $restaurant->getId())?->setIsAvailable(false);
        $this->entityManager->flush();
        $this->entityManager->clear();
        $result = $this->popular();
        self::assertNotContains("{$this->tag} Cached", array_column($result['restaurants'], 'name'));
        self::assertNotContains('Plat du cache', array_column($result['dishes'], 'name'));
    }

    public function testADeliveredOrderClearsTheCachedRanking(): void
    {
        $this->client->disableReboot();
        $this->popular();
        self::assertSame([], $this->rankingQueries(fn () => $this->popular()), 'cached');

        $delivery = (new Delivery())->setStatus(DeliveryStatus::DELIVERED);
        self::getContainer()->get(EventDispatcherInterface::class)->dispatch(
            new DeliveryStatusChangedEvent($delivery, DeliveryStatus::ON_THE_WAY)
        );

        self::assertNotSame([], $this->rankingQueries(fn () => $this->popular()), 'ranked again');
    }

    /**
     * The counting queries behind the ranking that [request] ran.
     *
     * @return list<string>
     */
    private function rankingQueries(callable $request): array
    {
        $this->entityManager->clear();
        QueryCounter::reset();
        $request();

        return array_values(array_filter(QueryCounter::$queries, static fn (string $sql) => str_contains($sql, 'COUNT(')));
    }

    public function testNeedsAnAccount(): void
    {
        $this->client->getCookieJar()->clear();
        $this->client->request('GET', '/api/popular');

        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    /**
     * @param list<string> $dishes
     *
     * @return list<Restaurant|Product>
     */
    private function restaurantWith(string $name, array $dishes, bool $open = true): array
    {
        $restaurant = (new Restaurant())->setName("{$this->tag} {$name}")->setIsAvailable($open);
        $category = (new Category())->setName('Menu')->setRestaurant($restaurant);
        $this->entityManager->persist($restaurant);
        $this->entityManager->persist($category);

        $products = [];
        foreach ($dishes as $dish) {
            $product = (new Product())
                ->setName($dish)
                ->setPrice('10.000')
                ->setIsAvailable(true)
                ->setRestaurant($restaurant)
                ->setCategory($category);
            $this->entityManager->persist($product);
            $products[] = $product;
        }
        $this->entityManager->flush();

        return [$restaurant, ...$products];
    }

    /**
     * @param list<Product> $products
     */
    private function order(Restaurant $restaurant, array $products, OrderStatus $status = OrderStatus::COMPLETED): Order
    {
        $order = (new Order())
            ->setUser($this->user)
            ->setRestaurant($restaurant)
            ->setDeliveryAddress('Rue de Rome, Bizerte')
            ->setDeliveryZone($this->zone)
            ->setDeliveryFee('3.000')
            ->setTotalAmount('13.000')
            ->setStatus($status);
        foreach ($products as $product) {
            $order->addItem((new OrderItem())->setProduct($product)->setQuantity(1)->setUnitPrice('10.000'));
        }
        $this->entityManager->persist($order);
        $this->entityManager->flush();

        return $order;
    }

    /**
     * @return array{restaurants: list<array<string, mixed>>, dishes: list<array<string, mixed>>, windowDays: int}
     */
    private function popular(): array
    {
        $this->client->request('GET', '/api/popular', server: ['HTTP_AUTHORIZATION' => 'Bearer '.$this->token]);
        self::assertResponseIsSuccessful();

        return json_decode((string) $this->client->getResponse()->getContent(), true);
    }

    private function createUser(): User
    {
        $user = new User();
        $user->setName('Popular Client');
        $user->setPhone((string) random_int(20000000, 99999999));
        $user->setRoles(['ROLE_CLIENT']);
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
