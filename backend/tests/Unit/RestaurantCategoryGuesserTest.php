<?php

namespace App\Tests\Unit;

use App\Service\RestaurantCategoryGuesser;
use PHPUnit\Framework\TestCase;

final class RestaurantCategoryGuesserTest extends TestCase
{
    private RestaurantCategoryGuesser $guesser;

    protected function setUp(): void
    {
        $this->guesser = new RestaurantCategoryGuesser();
    }

    public function testTheRestaurantsOwnNameIsEnough(): void
    {
        self::assertTrue($this->guesser->fits('pizza', 'Pizzeria Roma', []));
        self::assertTrue($this->guesser->fits('burger', 'Best Burger', []));
        self::assertTrue($this->guesser->fits('grill', 'Le Grill', []));
        self::assertTrue($this->guesser->fits('coffee', 'Café des Délices', []));
    }

    public function testAMenuSectionCountsForEachOfItsDishes(): void
    {
        $menu = [['Reine', 'Pizzas'], ['4 Fromages', 'Pizzas'], ['Coca', 'Boissons']];

        self::assertTrue($this->guesser->fits('pizza', 'Davvero', $menu));
    }

    public function testASectionOfItsOwnIsEnoughOnABigMenu(): void
    {
        // A snack with 40 sandwiches and a pizza section: it does pizzas.
        $menu = array_fill(0, 40, ['Chawarma', 'Sandwichs']);
        $menu[] = ['Margherita', 'NOS PIZZAS'];
        $menu[] = ['Neptune', 'NOS PIZZAS'];

        self::assertTrue($this->guesser->fits('pizza', 'Cabana', $menu));
        // A one-dish section isn't.
        self::assertFalse($this->guesser->fits('pizza', 'Cabana', array_slice($menu, 0, 41)));
    }

    public function testAFewDishesOnABigMenuDontMakeIt(): void
    {
        // Two juices in a pizzeria: not a juice bar.
        $menu = array_fill(0, 18, ['Pizza Reine', 'Pizzas']);
        $menu[] = ['Jus d\'orange', null];
        $menu[] = ['Jus de fraise', null];

        self::assertTrue($this->guesser->fits('pizza', 'Davvero', $menu));
        self::assertFalse($this->guesser->fits('drink', 'Davvero', $menu));
    }

    public function testOneDishIsNeverEnough(): void
    {
        self::assertFalse($this->guesser->fits('pizza', 'Chez Ali', [['Pizza Reine', null]]));
        self::assertTrue($this->guesser->fits('pizza', 'Chez Ali', [['Pizza Reine', null], ['Calzone', null]]));
    }

    public function testAccentsAndCaseDontMatter(): void
    {
        $menu = [['PÂTES carbonara', null], ['Lasagne', null]];

        self::assertTrue($this->guesser->fits('pasta', 'Mamma', $menu));
        self::assertTrue($this->guesser->fits('cake', 'Les Crêpes de Sousse', []));
    }

    public function testWholeWordsOnly(): void
    {
        // "grillé" is a way of cooking, not a grill house; "thé" isn't "the".
        $menu = [['Sandwich poulet grillé', null], ['Panini thon grillé', null]];

        self::assertFalse($this->guesser->fits('grill', 'Snack Ali', $menu));
        self::assertTrue($this->guesser->fits('fast_food', 'Snack Ali', $menu));
    }

    public function testIconsWithoutAClearFoodAreNeverGuessed(): void
    {
        foreach (['restaurant', 'croissant', 'tapas', 'soup', 'basket'] as $icon) {
            self::assertFalse($this->guesser->canGuess($icon));
            self::assertFalse($this->guesser->fits($icon, 'Croissant Doré Restaurant', []));
        }
    }
}
