<?php

namespace App\Tests\Integration;

use App\Entity\Restaurant;
use App\Entity\RestaurantCategory;
use App\Entity\User;
use App\Enum\RestaurantType;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\File\UploadedFile;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * Restaurant categories ("Pizza", "Sucré"...): managed by the admin, set on
 * restaurants, and used by clients to filter the restaurant list.
 */
final class RestaurantCategoryApiTest extends WebTestCase
{
    private EntityManagerInterface $entityManager;
    private KernelBrowser $client;

    protected function setUp(): void
    {
        $this->client = static::createClient();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
    }

    public function testAdminCanCreateEditAndDeleteACategory(): void
    {
        $token = $this->signIn('ROLE_ADMIN');
        $name = $this->uniqueName('Grillades');

        $created = $this->json('POST', '/api/admin/restaurant-categories', $token, [
            'name' => '  '.$name.'  ',
            'icon' => 'grill',
            'position' => 7,
        ]);

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        self::assertSame($name, $created['name']);
        self::assertSame('grill', $created['icon']);
        self::assertSame(7, $created['position']);
        self::assertNull($created['imageUrl']);

        $renamed = $this->uniqueName('Barbecue');

        $updated = $this->json('PUT', '/api/admin/restaurant-categories/'.$created['id'], $token, [
            'name' => $renamed,
            'icon' => 'kebab',
            'position' => 2,
        ]);

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
        self::assertSame($renamed, $updated['name']);
        self::assertSame('kebab', $updated['icon']);
        self::assertSame(2, $updated['position']);

        $listed = $this->json('GET', '/api/admin/restaurant-categories', $token);

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $row = $this->find($listed, $created['id']);

        self::assertNotNull($row);
        self::assertSame($renamed, $row['name']);
        self::assertSame(0, $row['restaurantCount']);

        $this->json('DELETE', '/api/admin/restaurant-categories/'.$created['id'], $token);

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $listed = $this->json('GET', '/api/admin/restaurant-categories', $token);

        self::assertNull($this->find($listed, $created['id']));
    }

    public function testACategoryWithoutAnIconGetsTheDefaultOne(): void
    {
        $token = $this->signIn('ROLE_ADMIN');

        $created = $this->json('POST', '/api/admin/restaurant-categories', $token, [
            'name' => $this->uniqueName('Divers'),
            'position' => 0,
        ]);

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        self::assertSame('restaurant', $created['icon']);
    }

    public function testTwoCategoriesCannotShareAName(): void
    {
        $token = $this->signIn('ROLE_ADMIN');
        $name = $this->uniqueName('Crêpes');

        $this->json('POST', '/api/admin/restaurant-categories', $token, ['name' => $name, 'position' => 0]);
        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);

        $this->json('POST', '/api/admin/restaurant-categories', $token, ['name' => $name, 'position' => 1]);
        self::assertResponseStatusCodeSame(Response::HTTP_CONFLICT);
    }

    public function testInvalidCategoryDataIsRejected(): void
    {
        $token = $this->signIn('ROLE_ADMIN');

        $this->json('POST', '/api/admin/restaurant-categories', $token, ['name' => '   ', 'position' => 0]);
        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);

        $this->json('POST', '/api/admin/restaurant-categories', $token, [
            'name' => $this->uniqueName('Sushi'),
            'icon' => 'not-an-icon',
            'position' => 0,
        ]);
        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    public function testEditingOrDeletingAnUnknownCategoryReturns404(): void
    {
        $token = $this->signIn('ROLE_ADMIN');

        $this->json('PUT', '/api/admin/restaurant-categories/999999', $token, ['name' => 'Nope', 'position' => 0]);
        self::assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND);

        $this->json('DELETE', '/api/admin/restaurant-categories/999999', $token);
        self::assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND);
    }

    public function testNonAdminCannotManageCategories(): void
    {
        $token = $this->signIn('ROLE_CLIENT');

        $this->json('GET', '/api/admin/restaurant-categories', $token);
        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);

        $this->json('POST', '/api/admin/restaurant-categories', $token, ['name' => 'Hack', 'position' => 0]);
        self::assertResponseStatusCodeSame(Response::HTTP_FORBIDDEN);
    }

    public function testAdminCanUploadAndRemoveACategoryImage(): void
    {
        $token = $this->signIn('ROLE_ADMIN');
        $category = $this->createCategory('Glaces');

        $this->client->request(
            'POST',
            '/api/admin/restaurant-categories/'.$category->getId().'/image',
            server: ['HTTP_AUTHORIZATION' => 'Bearer '.$token],
            files: ['image' => $this->createPngUploadedFile()]
        );

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $uploaded = json_decode($this->client->getResponse()->getContent(), true);

        self::assertStringStartsWith('/uploads/restaurant-categories/', $uploaded['imageUrl']);

        $path = self::getContainer()->getParameter('kernel.project_dir').'/public'.$uploaded['imageUrl'];

        self::assertFileExists($path);

        $removed = $this->json('DELETE', '/api/admin/restaurant-categories/'.$category->getId().'/image', $token);

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
        self::assertNull($removed['imageUrl']);
        self::assertFileDoesNotExist($path);
    }

    public function testAdminSetsARestaurantsCategoriesWhenCreatingAndEditingIt(): void
    {
        $token = $this->signIn('ROLE_ADMIN');
        $pizza = $this->createCategory('Pizza', position: 1);
        $sweet = $this->createCategory('Sucré', position: 2);
        $drinks = $this->createCategory('Boissons', position: 3);

        $created = $this->json('POST', '/api/admin/restaurants', $token, [
            'name' => 'Categorised Diner',
            'isAvailable' => true,
            // Not in display order: the answer is sorted by position.
            'categoryIds' => [$sweet->getId(), $pizza->getId()],
        ]);

        self::assertResponseStatusCodeSame(Response::HTTP_CREATED);
        self::assertSame(
            [$pizza->getId(), $sweet->getId()],
            array_column($created['categories'], 'id')
        );
        self::assertSame($pizza->getName(), $created['categories'][0]['name']);

        // A form that doesn't send categoryIds leaves them as they are.
        $renamed = $this->json('PUT', '/api/admin/restaurants/'.$created['id'], $token, [
            'name' => 'Categorised Diner II',
            'isAvailable' => true,
        ]);

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
        self::assertCount(2, $renamed['categories']);

        $changed = $this->json('PUT', '/api/admin/restaurants/'.$created['id'], $token, [
            'name' => 'Categorised Diner II',
            'isAvailable' => true,
            'categoryIds' => [$drinks->getId()],
        ]);

        self::assertSame([$drinks->getId()], array_column($changed['categories'], 'id'));

        $shown = $this->json('GET', '/api/admin/restaurants/'.$created['id'], $token);

        self::assertSame([$drinks->getId()], array_column($shown['categories'], 'id'));

        $listed = $this->json('GET', '/api/admin/restaurant-categories', $token);

        self::assertSame(1, $this->find($listed, $drinks->getId())['restaurantCount']);
        self::assertSame(0, $this->find($listed, $pizza->getId())['restaurantCount']);

        $cleared = $this->json('PUT', '/api/admin/restaurants/'.$created['id'], $token, [
            'name' => 'Categorised Diner II',
            'isAvailable' => true,
            'categoryIds' => [],
        ]);

        self::assertSame([], $cleared['categories']);
    }

    public function testARestaurantCannotGetACategoryThatDoesNotExist(): void
    {
        $token = $this->signIn('ROLE_ADMIN');

        $response = $this->json('POST', '/api/admin/restaurants', $token, [
            'name' => 'Ghost Category Diner',
            'isAvailable' => true,
            'categoryIds' => [999999],
        ]);

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
        self::assertSame('categoryIds', $response['errors'][0]['field']);

        $this->json('POST', '/api/admin/restaurants', $token, [
            'name' => 'Ghost Category Diner',
            'isAvailable' => true,
            'categoryIds' => ['pizza'],
        ]);

        self::assertResponseStatusCodeSame(Response::HTTP_UNPROCESSABLE_ENTITY);
    }

    public function testDeletingACategoryKeepsItsRestaurants(): void
    {
        $token = $this->signIn('ROLE_ADMIN');
        $category = $this->createCategory('Éphémère');
        $restaurant = $this->createRestaurant('Survivor Diner', categories: [$category]);

        $this->json('DELETE', '/api/admin/restaurant-categories/'.$category->getId(), $token);

        self::assertResponseStatusCodeSame(Response::HTTP_NO_CONTENT);

        $shown = $this->json('GET', '/api/admin/restaurants/'.$restaurant->getId(), $token);

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
        self::assertSame([], $shown['categories']);
    }

    public function testClientFiltersRestaurantsByCategory(): void
    {
        $token = $this->signIn('ROLE_CLIENT');
        $pizza = $this->createCategory('Pizza');
        $sweet = $this->createCategory('Sucré');

        $this->createRestaurant('Filter Pizzeria', categories: [$pizza]);
        $this->createRestaurant('Filter Pizza & Crêpes', categories: [$pizza, $sweet]);
        $this->createRestaurant('Filter Pâtisserie', categories: [$sweet]);
        $this->createRestaurant('Filter Plain Diner');
        $this->createRestaurant('Filter Closed Pizzeria', isAvailable: false, categories: [$pizza]);
        $this->createRestaurant('Filter Pizza Grocery', type: RestaurantType::GROCERY, categories: [$pizza]);

        $names = fn (array $response) => array_values(array_filter(
            array_column($response['items'], 'name'),
            static fn ($name) => str_starts_with($name, 'Filter ')
        ));

        $filtered = $this->json('GET', '/api/restaurants?limit=100&category='.$pizza->getId(), $token);

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
        self::assertSame(['Filter Pizza & Crêpes', 'Filter Pizzeria'], $names($filtered));
        self::assertSame(2, $filtered['meta']['total']);

        // Each restaurant says what it serves, for the labels on its card.
        $both = current(array_filter($filtered['items'], static fn ($r) => 'Filter Pizza & Crêpes' === $r['name']));

        self::assertEqualsCanonicalizing(
            [$pizza->getId(), $sweet->getId()],
            array_column($both['categories'], 'id')
        );
        self::assertArrayHasKey('icon', $both['categories'][0]);
        self::assertArrayHasKey('imageUrl', $both['categories'][0]);

        // Combined with the type filter.
        $groceries = $this->json('GET', '/api/restaurants?type=GROCERY&category='.$pizza->getId(), $token);

        self::assertSame(['Filter Pizza Grocery'], $names($groceries));

        // No filter (or one that isn't an id): everything, as before.
        $all = $this->json('GET', '/api/restaurants?limit=100', $token);

        self::assertContains('Filter Plain Diner', $names($all));
        self::assertContains('Filter Pizzeria', $names($all));

        $ignored = $this->json('GET', '/api/restaurants?limit=100&category=abc', $token);

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
        self::assertContains('Filter Plain Diner', $names($ignored));

        // A category nobody has: an empty list, not an error.
        $none = $this->json('GET', '/api/restaurants?category=999999', $token);

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
        self::assertSame([], $none['items']);
    }

    public function testClientOnlySeesCategoriesWithAnOpenRestaurant(): void
    {
        $token = $this->signIn('ROLE_CLIENT');
        $open = $this->createCategory('Ouvert', position: 2);
        $first = $this->createCategory('Premier', position: 1);
        $closedOnly = $this->createCategory('Fermé');
        $groceryOnly = $this->createCategory('Épicerie');
        $unused = $this->createCategory('Vide');

        $this->createRestaurant('In Use Diner', categories: [$open, $first]);
        $this->createRestaurant('In Use Closed Diner', isAvailable: false, categories: [$closedOnly]);
        $this->createRestaurant('In Use Grocery', type: RestaurantType::GROCERY, categories: [$groceryOnly]);

        $restaurants = $this->json('GET', '/api/restaurant-categories', $token);

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        $ids = array_column($restaurants, 'id');

        self::assertContains($open->getId(), $ids);
        self::assertContains($first->getId(), $ids);
        self::assertNotContains($closedOnly->getId(), $ids);
        self::assertNotContains($groceryOnly->getId(), $ids);
        self::assertNotContains($unused->getId(), $ids);

        // In the admin's order.
        self::assertLessThan(
            array_search($open->getId(), $ids, true),
            array_search($first->getId(), $ids, true)
        );

        $listed = $this->find($restaurants, $open->getId());

        self::assertSame($open->getName(), $listed['name']);
        self::assertSame('restaurant', $listed['icon']);
        self::assertNull($listed['imageUrl']);

        $groceries = $this->json('GET', '/api/restaurant-categories?type=GROCERY', $token);
        $groceryIds = array_column($groceries, 'id');

        self::assertContains($groceryOnly->getId(), $groceryIds);
        self::assertNotContains($open->getId(), $groceryIds);
    }

    public function testCategoriesNeedASignedInAccount(): void
    {
        $this->client->request('GET', '/api/restaurant-categories');

        self::assertResponseStatusCodeSame(Response::HTTP_UNAUTHORIZED);
    }

    public function testSearchResultsCarryTheirCategories(): void
    {
        $token = $this->signIn('ROLE_CLIENT');
        $category = $this->createCategory('Trouvable');

        $this->createRestaurant('Zyxsearchable Diner', categories: [$category]);

        $results = $this->json('GET', '/api/search?q=zyxsearchable', $token);

        self::assertResponseStatusCodeSame(Response::HTTP_OK);
        self::assertSame(
            [$category->getId()],
            array_column($results['restaurants'][0]['categories'], 'id')
        );
    }

    /**
     * @return array<mixed>|null the decoded answer
     */
    private function json(string $method, string $url, string $token, ?array $body = null): ?array
    {
        $this->client->request(
            $method,
            $url,
            server: [
                'CONTENT_TYPE' => 'application/json',
                'HTTP_AUTHORIZATION' => 'Bearer '.$token,
            ],
            content: null === $body ? null : json_encode($body)
        );

        $content = $this->client->getResponse()->getContent();

        return '' === $content ? null : json_decode($content, true);
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     *
     * @return array<string, mixed>|null
     */
    private function find(array $rows, int $id): ?array
    {
        foreach ($rows as $row) {
            if ($row['id'] === $id) {
                return $row;
            }
        }

        return null;
    }

    private function signIn(string $role): string
    {
        $user = new User();

        $user->setName('Test '.$role);
        $user->setPhone('2'.random_int(10000000, 99999999));
        $user->setRoles([$role]);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setPassword(
            self::getContainer()->get(UserPasswordHasherInterface::class)->hashPassword($user, 'password123')
        );

        $this->entityManager->persist($user);
        $this->entityManager->flush();

        $this->client->request(
            'POST',
            '/api/auth/login',
            server: ['CONTENT_TYPE' => 'application/json'],
            content: json_encode(['phone' => $user->getPhone(), 'password' => 'password123'])
        );

        self::assertResponseStatusCodeSame(Response::HTTP_OK);

        return json_decode($this->client->getResponse()->getContent(), true)['token'];
    }

    /**
     * The test database is shared by every test, and names are unique.
     */
    private function uniqueName(string $name): string
    {
        return $name.' '.bin2hex(random_bytes(4));
    }

    private function createCategory(string $name, int $position = 0): RestaurantCategory
    {
        $category = (new RestaurantCategory())
            ->setName($this->uniqueName($name))
            ->setPosition($position);

        $this->entityManager->persist($category);
        $this->entityManager->flush();

        return $category;
    }

    /**
     * @param RestaurantCategory[] $categories
     */
    private function createRestaurant(
        string $name,
        bool $isAvailable = true,
        RestaurantType $type = RestaurantType::RESTAURANT,
        array $categories = [],
    ): Restaurant {
        $restaurant = (new Restaurant())
            ->setName($name)
            ->setDescription(null)
            ->setIsAvailable($isAvailable)
            ->setType($type)
            ->setRestaurantCategories($categories);

        $this->entityManager->persist($restaurant);
        $this->entityManager->flush();

        return $restaurant;
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
}
