<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\RestaurantType;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * "Rechercher un plat, un restaurant": finds dishes too, and only what can
 * be ordered right now.
 */
final class SearchApiTest extends WebTestCase
{
    private KernelBrowser $client;
    private EntityManagerInterface $entityManager;
    private string $token;
    private string $tag;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        // Unique per run, so earlier runs' rows never match.
        $this->tag = 'zq'.random_int(100000, 999999);
        $this->token = $this->login($this->createUser());
    }

    public function testFindsDishesWithTheirRestaurantAndRestaurantsByName(): void
    {
        $pizzeria = $this->createRestaurant("Pizzeria {$this->tag}", true);
        $grocery = $this->createRestaurant("Épicerie {$this->tag}", true, RestaurantType::GROCERY);
        $closed = $this->createRestaurant("Fermé {$this->tag}", false);

        $this->createProduct($pizzeria, "Pizza {$this->tag} Margherita", true);
        $this->createProduct($pizzeria, "Pizza {$this->tag} Hidden", false);
        $this->createProduct($grocery, "Lait {$this->tag}", true);
        $this->createProduct($closed, "Pizza {$this->tag} Closed", true);

        $result = $this->search(strtoupper($this->tag));

        self::assertEqualsCanonicalizing(
            ["Pizzeria {$this->tag}", "Épicerie {$this->tag}"],
            array_column($result['restaurants'], 'name')
        );
        self::assertEqualsCanonicalizing(
            ["Pizza {$this->tag} Margherita", "Lait {$this->tag}"],
            array_column($result['products'], 'name')
        );

        $dish = $this->search("pizza {$this->tag}")['products'];
        self::assertCount(1, $dish);
        self::assertSame($pizzeria->getId(), $dish[0]['restaurant']['id']);
        self::assertSame("Pizzeria {$this->tag}", $dish[0]['restaurant']['name']);
        self::assertSame('10.000', $dish[0]['price']);
    }

    public function testTooShortOrWildcardSearchesFindNothing(): void
    {
        $restaurant = $this->createRestaurant("Snack {$this->tag}", true);
        $this->createProduct($restaurant, "Sandwich {$this->tag}", true);

        self::assertSame(['restaurants' => [], 'products' => []], $this->search('s'));
        self::assertSame([], $this->search("{$this->tag}%_")['products']);
    }

    public function testSearchNeedsAnAccount(): void
    {
        $this->client->getCookieJar()->clear(); // setUp's login cookie
        $this->client->request('GET', '/api/search?q=pizza');

        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    /**
     * @return array{restaurants: list<array<string, mixed>>, products: list<array<string, mixed>>}
     */
    private function search(string $term): array
    {
        $this->client->request('GET', '/api/search?'.http_build_query(['q' => $term]), server: [
            'HTTP_AUTHORIZATION' => 'Bearer '.$this->token,
        ]);
        self::assertResponseIsSuccessful();

        return json_decode((string) $this->client->getResponse()->getContent(), true);
    }

    private function createRestaurant(string $name, bool $available, RestaurantType $type = RestaurantType::RESTAURANT): Restaurant
    {
        $restaurant = (new Restaurant())->setName($name)->setIsAvailable($available)->setType($type);
        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        return $restaurant;
    }

    private function createProduct(Restaurant $restaurant, string $name, bool $available): Product
    {
        $category = (new Category())->setName('Plats')->setRestaurant($restaurant);
        $product = (new Product())
            ->setName($name)
            ->setPrice('10.000')
            ->setIsAvailable($available)
            ->setRestaurant($restaurant)
            ->setCategory($category);
        $this->entityManager->persist($category);
        $this->entityManager->persist($product);
        $this->entityManager->flush();

        return $product;
    }

    private function createUser(): User
    {
        $user = new User();
        $user->setName('Search Client');
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
