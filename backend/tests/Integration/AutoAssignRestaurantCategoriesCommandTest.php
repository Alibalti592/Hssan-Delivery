<?php

namespace App\Tests\Integration;

use App\Entity\Category;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\RestaurantCategory;
use App\Enum\RestaurantType;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Symfony\Component\Console\Tester\CommandTester;

final class AutoAssignRestaurantCategoriesCommandTest extends KernelTestCase
{
    private EntityManagerInterface $entityManager;
    private CommandTester $command;

    protected function setUp(): void
    {
        $kernel = self::bootKernel();
        $this->entityManager = self::getContainer()->get(EntityManagerInterface::class);
        $this->command = new CommandTester(
            (new Application($kernel))->find('app:restaurant-categories:auto-assign')
        );
    }

    public function testListsWithoutSavingThenSavesWithApply(): void
    {
        $pizza = $this->category('pizza');
        $sweet = $this->category('cake');
        $pizzeria = $this->restaurant('Auto Pizzeria '.uniqid(), [['Reine', 'Pizzas'], ['Calzone', 'Pizzas']]);
        $diner = $this->restaurant('Auto Diner '.uniqid(), [['Steak frites', 'Plats']]);

        $this->command->execute([]);
        self::assertStringContainsString($pizzeria->getName(), $this->command->getDisplay());
        self::assertStringContainsString('not saved', $this->command->getDisplay());
        self::assertSame([], $this->categoriesOf($pizzeria, [$pizza, $sweet]));

        $this->command->execute(['--apply' => true]);
        self::assertStringContainsString('saved', $this->command->getDisplay());
        self::assertSame([$pizza->getId()], $this->categoriesOf($pizzeria, [$pizza, $sweet]));
        self::assertSame([], $this->categoriesOf($diner, [$pizza, $sweet]));
    }

    public function testOnlyAddsNeverRemoves(): void
    {
        $pizza = $this->category('pizza');
        $sweet = $this->category('cake');
        // Ticked by the admin, though the menu says nothing sweet: kept.
        $pizzeria = $this->restaurant('Kept Pizzeria '.uniqid(), [['Reine', 'Pizzas'], ['Margherita', 'Pizzas']], [$sweet]);

        $this->command->execute(['--apply' => true]);

        self::assertEqualsCanonicalizing(
            [$sweet->getId(), $pizza->getId()],
            $this->categoriesOf($pizzeria, [$pizza, $sweet]),
        );
    }

    public function testGroceryStoresAreLeftAlone(): void
    {
        $drink = $this->category('drink');
        $store = $this->restaurant('Auto Jus Market '.uniqid(), [], type: RestaurantType::GROCERY);

        $this->command->execute(['--apply' => true]);

        self::assertSame([], $this->categoriesOf($store, [$drink]));
    }

    private function category(string $icon): RestaurantCategory
    {
        $category = (new RestaurantCategory())->setName('Auto '.$icon.' '.uniqid())->setIcon($icon);
        $this->entityManager->persist($category);
        $this->entityManager->flush();

        return $category;
    }

    /**
     * @param list<array{0: string, 1: string}> $dishes
     * @param RestaurantCategory[]              $categories
     */
    private function restaurant(
        string $name,
        array $dishes,
        array $categories = [],
        RestaurantType $type = RestaurantType::RESTAURANT,
    ): Restaurant {
        $restaurant = (new Restaurant())->setName($name)->setDescription(null)->setType($type)
            ->setRestaurantCategories($categories);
        $this->entityManager->persist($restaurant);

        $sections = [];
        foreach ($dishes as [$dish, $section]) {
            if (!isset($sections[$section])) {
                $sections[$section] = (new Category())->setName($section)->setRestaurant($restaurant);
                $this->entityManager->persist($sections[$section]);
            }
            $this->entityManager->persist((new Product())
                ->setName($dish)
                ->setPrice('10.000')
                ->setRestaurant($restaurant)
                ->setCategory($sections[$section]));
        }
        $this->entityManager->flush();

        return $restaurant;
    }

    /**
     * Which of [$among] the restaurant is in (the database also holds
     * other tests' categories, which the command may tick too).
     *
     * @param RestaurantCategory[] $among
     *
     * @return list<int>
     */
    private function categoriesOf(Restaurant $restaurant, array $among): array
    {
        $ids = array_map('intval', $this->entityManager->getConnection()->fetchFirstColumn(
            'SELECT restaurant_category_id FROM restaurant_restaurant_category WHERE restaurant_id = ? ORDER BY restaurant_category_id',
            [$restaurant->getId()]
        ));

        return array_values(array_intersect($ids, array_map(fn ($c) => $c->getId(), $among)));
    }
}
