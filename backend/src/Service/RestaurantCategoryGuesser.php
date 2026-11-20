<?php

namespace App\Service;

/**
 * Guesses which restaurant categories fit a restaurant from what it sells,
 * for the restaurants nobody ticked yet (app:restaurant-categories:auto-assign).
 *
 * Goes by the category's icon, so it works with the admin's own names
 * ("Pizza", "Pizzeria"...). A restaurant fits a category when:
 * - its own name says so ("Pizza Roma");
 * - or its menu has a section for it, of 2 dishes or more ("NOS PIZZAS");
 * - or enough of its dishes say so: 2 or more, and at least 15% of the
 *   menu. A pizzeria's two juices don't make it a juice bar.
 *
 * Icons without a clear food behind them (restaurant, tapas, soup, basket,
 * croissant: "Salé" in the client's list) are never guessed.
 */
final class RestaurantCategoryGuesser
{
    private const MIN_DISHES = 2;
    private const MIN_SHARE = 0.15;

    /**
     * Per icon, the words that point to it, on lowercase text without
     * accents.
     */
    private const PATTERNS = [
        'pizza' => 'pizz\w*|margherita|calzone',
        'burger' => '\w*burgers?',
        'fast_food' => 'sandwich\w*|panini\w*|panuozzo|tacos|hot ?dogs?|wraps?|makloub\w*|mlawi|chapati|baguettes? farcies?|cornets?|libanais\w*|fast ?food|nuggets',
        'kebab' => 'chawarma|shawarma|kebab|kabab|doner|chich',
        'grill' => 'grill|grillades?|brochettes?|mechoui|merguez|kefta',
        'bowl' => 'couscous|ojja|lablabi|lablebi|kafteji|tajine|chorba|briks?|mloukhia|kamounia|tunisien\w*|traditionnel\w*',
        'pasta' => 'pates|pasta|spaghetti\w*|penne|lasagnes?|tagliatelle\w*|macaroni|rigatoni|fettuccine|carbonara|bolognaise',
        'fish' => 'poissons?|fruits de mer|crevettes?|calamars?|dorade|loup de mer|saumon|sushis?',
        'leaf' => 'salades?',
        'breakfast' => 'petits?[- ]dejeuners?|omelettes?|brunch',
        'cake' => 'desserts?|gateaux?|patisseries?|tartes?|cheesecake|tiramisu|fondant|baklawa|crepes?|gaufres?|waffles?|pancakes?|donuts?|cookies?|sucres?',
        'ice_cream' => 'glaces?|gelato|sorbets?|ice ?creams?|coupes? glacees?',
        'coffee' => 'cafes?|cappuccino|espresso|expresso|latte|macchiato',
        'drink' => 'jus|smoothies?|mojitos?|milk ?shakes?|cocktails?|citronnade',
    ];

    public function canGuess(string $icon): bool
    {
        return isset(self::PATTERNS[$icon]);
    }

    /**
     * @param list<array{0: string, 1: ?string}> $dishes each dish's name and
     *                                                   its menu section's
     */
    public function fits(string $icon, string $restaurantName, array $dishes): bool
    {
        if (!$this->canGuess($icon)) {
            return false;
        }
        $pattern = '/\b(?:'.self::PATTERNS[$icon].')\b/u';

        if (preg_match($pattern, self::plain($restaurantName))) {
            return true;
        }

        $matching = 0;
        $bySection = [];
        foreach ($dishes as [$name, $section]) {
            if (null !== $section && preg_match($pattern, self::plain($section))) {
                $bySection[$section] = ($bySection[$section] ?? 0) + 1;
                if (self::MIN_DISHES === $bySection[$section]) {
                    return true;
                }
            }
            if (preg_match($pattern, self::plain($name.' | '.($section ?? '')))) {
                ++$matching;
            }
        }

        return $matching >= self::MIN_DISHES && $matching >= self::MIN_SHARE * count($dishes);
    }

    private static function plain(string $text): string
    {
        return strtr(mb_strtolower($text), [
            'à' => 'a', 'â' => 'a', 'ä' => 'a',
            'é' => 'e', 'è' => 'e', 'ê' => 'e', 'ë' => 'e',
            'î' => 'i', 'ï' => 'i',
            'ô' => 'o', 'ö' => 'o',
            'ù' => 'u', 'û' => 'u', 'ü' => 'u',
            'ç' => 'c', 'œ' => 'oe',
        ]);
    }
}
