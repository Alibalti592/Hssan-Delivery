<?php

namespace App\DataFixtures;

use App\Entity\Category;
use App\Entity\Delivery;
use App\Entity\DeliveryZone;
use App\Entity\Order;
use App\Entity\OrderItem;
use App\Entity\Product;
use App\Entity\Restaurant;
use App\Entity\User;
use App\Enum\DeliveryStatus;
use App\Util\Money;
use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

/**
 * Development seed data: one account per role, a small catalogue, and a few
 * orders/deliveries in different lifecycle states so every dashboard screen
 * has something to show.
 *
 * Credentials (all environments seeded with this fixture):
 *   admin    20000000 / admin1234
 *   courier  21000001 / courier1234   (active)
 *   courier  21000002 / courier1234   (deactivated — for the "can't log in" path)
 *   client   22000001 / client1234
 *   client   22000002 / client1234
 *
 * Safe to run with --append: if the admin account already exists the fixture
 * does nothing. Delivery zones come from a migration, so this never touches them.
 */
class AppFixtures extends Fixture
{
    private const ADMIN_PHONE = '20000000';

    public function __construct(
        private readonly UserPasswordHasherInterface $passwordHasher,
    ) {
    }

    public function load(ObjectManager $manager): void
    {
        if (null !== $manager->getRepository(User::class)->findOneBy(['phone' => self::ADMIN_PHONE])) {
            return;
        }

        $this->createUser($manager, 'Admin', self::ADMIN_PHONE, 'admin1234', ['ROLE_ADMIN']);
        $activeCourier = $this->createUser($manager, 'Awa Courier', '21000001', 'courier1234', ['ROLE_LIVREUR']);
        $this->createUser($manager, 'Retired Courier', '21000002', 'courier1234', ['ROLE_LIVREUR'], isActive: false);
        $client1 = $this->createUser($manager, 'Sami Client', '22000001', 'client1234', ['ROLE_CLIENT']);
        $client2 = $this->createUser($manager, 'Nadia Client', '22000002', 'client1234', ['ROLE_CLIENT']);

        $burgers = $this->createRestaurant($manager, 'Le Bon Burger', 'Smash burgers and loaded fries.', [
            'Burgers' => [
                ['Classic Smash', '12.500'],
                ['Double Cheese', '16.000'],
                ['Chicken Crunch', '13.500'],
            ],
            'Sides' => [
                ['Loaded Fries', '7.000'],
                ['Onion Rings', '5.500'],
            ],
        ]);

        $pizza = $this->createRestaurant($manager, 'Napoli Express', 'Wood-fired Neapolitan pizza.', [
            'Pizze' => [
                ['Margherita', '11.000'],
                ['Diavola', '14.000'],
                ['Quattro Formaggi', '15.500'],
            ],
            'Desserts' => [
                ['Tiramisu', '6.000'],
            ],
        ]);

        $zone = $manager->getRepository(DeliveryZone::class)->findOneBy([]);

        if (null === $zone) {
            $zone = new DeliveryZone();
            $zone->setName('Bizerte centre');
            $zone->setFee('4.000');
            $manager->persist($zone);
        }

        // A brand-new order still waiting for a courier.
        $this->createOrder($manager, $client1, $burgers, $zone, [
            [$this->product($burgers, 'Classic Smash'), 2],
            [$this->product($burgers, 'Loaded Fries'), 1],
        ], DeliveryStatus::PENDING, null);

        // An order a courier has been assigned to but not yet picked up.
        $this->createOrder($manager, $client2, $pizza, $zone, [
            [$this->product($pizza, 'Diavola'), 1],
            [$this->product($pizza, 'Tiramisu'), 2],
        ], DeliveryStatus::ASSIGNED, $activeCourier);

        // A completed delivery for history.
        $this->createOrder($manager, $client1, $burgers, $zone, [
            [$this->product($burgers, 'Double Cheese'), 1],
        ], DeliveryStatus::DELIVERED, $activeCourier);

        $manager->flush();
    }

    /**
     * @param list<string> $roles
     */
    private function createUser(
        ObjectManager $manager,
        string $name,
        string $phone,
        string $plainPassword,
        array $roles,
        bool $isActive = true,
    ): User {
        $user = new User();
        $user->setName($name);
        $user->setPhone($phone);
        $user->setRoles($roles);
        $user->setVerifiedAt(new \DateTimeImmutable());
        $user->setActive($isActive);
        $user->setPassword($this->passwordHasher->hashPassword($user, $plainPassword));

        $manager->persist($user);

        return $user;
    }

    /**
     * @param array<string, list<array{0: string, 1: string}>> $catalogue category name => [[product name, price], ...]
     */
    private function createRestaurant(
        ObjectManager $manager,
        string $name,
        string $description,
        array $catalogue,
    ): Restaurant {
        $restaurant = new Restaurant();
        $restaurant->setName($name);
        $restaurant->setDescription($description);
        $restaurant->setIsAvailable(true);
        $manager->persist($restaurant);

        foreach ($catalogue as $categoryName => $products) {
            $category = new Category();
            $category->setName($categoryName);
            $category->setRestaurant($restaurant);
            $manager->persist($category);

            foreach ($products as [$productName, $price]) {
                $product = new Product();
                $product->setName($productName);
                $product->setPrice($price);
                $product->setIsAvailable(true);
                $restaurant->addProduct($product);
                $category->addProduct($product);
                $manager->persist($product);
            }
        }

        return $restaurant;
    }

    private function product(Restaurant $restaurant, string $name): Product
    {
        foreach ($restaurant->getProducts() as $product) {
            if ($product->getName() === $name) {
                return $product;
            }
        }

        throw new \LogicException(sprintf('Seed product "%s" not found on restaurant "%s".', $name, $restaurant->getName()));
    }

    /**
     * @param list<array{0: Product, 1: int}> $lines product => quantity
     */
    private function createOrder(
        ObjectManager $manager,
        User $customer,
        Restaurant $restaurant,
        DeliveryZone $zone,
        array $lines,
        DeliveryStatus $deliveryStatus,
        ?User $courier,
    ): void {
        $order = new Order();
        $order->setUser($customer);
        $order->setRestaurant($restaurant);
        $order->setDeliveryAddress('12 Rue de la Corniche, Bizerte');
        $order->setDeliveryZone($zone);

        $itemsMillimes = 0;

        foreach ($lines as [$product, $quantity]) {
            $item = new OrderItem();
            $item->setProduct($product);
            $item->setQuantity($quantity);
            $item->setUnitPrice($product->getPrice());
            $order->addItem($item);

            $itemsMillimes += Money::toMillimes($product->getPrice()) * $quantity;
        }

        $feeMillimes = Money::toMillimes($zone->getFee());
        $order->setDeliveryFee(Money::fromMillimes($feeMillimes));
        $order->setTotalAmount(Money::fromMillimes($itemsMillimes + $feeMillimes));

        $delivery = new Delivery();
        $delivery->setOrder($order);
        $delivery->setStatus($deliveryStatus);

        $now = new \DateTimeImmutable();

        if (DeliveryStatus::PENDING !== $deliveryStatus && null !== $courier) {
            $delivery->setCourier($courier);
            $delivery->setAssignedAt($now);
        }

        if (DeliveryStatus::DELIVERED === $deliveryStatus) {
            $delivery->setAcceptedAt($now);
            $delivery->setPickedUpAt($now);
            $delivery->setDeliveredAt($now);
        }

        $order->setStatus($deliveryStatus->toOrderStatus());
        $order->setDelivery($delivery);

        $manager->persist($order);
        $manager->persist($delivery);
    }
}
