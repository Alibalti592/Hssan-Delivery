<?php

namespace App\Command;

use App\Entity\Restaurant;
use App\Enum\RestaurantType;
use App\Repository\RestaurantCategoryRepository;
use App\Service\RestaurantCategoryGuesser;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;

/**
 * Ticks restaurants into the categories their menus fit
 * (RestaurantCategoryGuesser), so the app's "Que souhaitez-vous manger ?"
 * row isn't left with the few the admin ticked by hand. A category only
 * shows in the app once an open restaurant is in it.
 *
 * Only adds: a category the admin ticked or unticked stays as it is for
 * everything already ticked, and nothing is ever removed. Without --apply
 * it only lists what it would add. The admin can correct any guess from
 * the restaurant's page.
 */
#[AsCommand(name: 'app:restaurant-categories:auto-assign', description: 'Tick restaurants into the categories their menus fit (lists only, unless --apply)')]
final class AutoAssignRestaurantCategoriesCommand extends Command
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly RestaurantCategoryRepository $categories,
        private readonly RestaurantCategoryGuesser $guesser,
    ) {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this->addOption('apply', null, InputOption::VALUE_NONE, 'Save the additions (otherwise they are only listed)');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);
        $apply = (bool) $input->getOption('apply');

        $categories = array_filter(
            $this->categories->findAllOrdered(),
            fn ($category) => $this->guesser->canGuess($category->getIcon()),
        );

        /** @var Restaurant[] $restaurants */
        $restaurants = $this->entityManager->createQuery(
            'SELECT r, p, c, rc FROM App\Entity\Restaurant r
             LEFT JOIN r.products p
             LEFT JOIN p.category c
             LEFT JOIN r.restaurantCategories rc
             WHERE r.type = :type
             ORDER BY r.name ASC'
        )->setParameter('type', RestaurantType::RESTAURANT)->getResult();

        $rows = [];
        $added = 0;
        foreach ($restaurants as $restaurant) {
            $dishes = [];
            foreach ($restaurant->getProducts() as $product) {
                $dishes[] = [(string) $product->getName(), $product->getCategory()?->getName()];
            }

            $current = $restaurant->getRestaurantCategories();
            $new = [];
            foreach ($categories as $category) {
                if (!$current->contains($category)
                    && $this->guesser->fits($category->getIcon(), (string) $restaurant->getName(), $dishes)) {
                    $new[] = $category;
                }
            }
            if ([] === $new) {
                continue;
            }

            $rows[] = [$restaurant->getName(), implode(', ', array_map(fn ($c) => $c->getName(), $new))];
            $added += count($new);
            if ($apply) {
                $restaurant->setRestaurantCategories([...$current->toArray(), ...$new]);
            }
        }

        if ([] === $rows) {
            $io->success('Nothing to add: every restaurant already has the categories its menu fits.');

            return Command::SUCCESS;
        }

        $io->table(['Restaurant', 'Categories added'], $rows);

        if (!$apply) {
            $io->note(sprintf('%d additions on %d restaurants, not saved. Run again with --apply to save them.', $added, count($rows)));

            return Command::SUCCESS;
        }

        $this->entityManager->flush();
        $io->success(sprintf('%d additions saved on %d restaurants.', $added, count($rows)));

        return Command::SUCCESS;
    }
}
