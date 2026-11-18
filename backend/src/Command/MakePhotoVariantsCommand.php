<?php

namespace App\Command;

use App\Service\PhotoVariants;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

/**
 * Makes the smaller copies (PhotoVariants) of photos uploaded before they
 * existed. Safe to run again: only missing copies are made, and the
 * originals aren't touched. New uploads get theirs straight away.
 */
#[AsCommand(name: 'app:photos:make-variants', description: 'Make the smaller copies of the catalogue photos that lack them')]
final class MakePhotoVariantsCommand extends Command
{
    public function __construct(
        private readonly PhotoVariants $variants,
        #[Autowire('%kernel.project_dir%/public/uploads')]
        private readonly string $uploadsDir,
    ) {
        parent::__construct();
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);
        $photos = glob($this->uploadsDir.'/*/*.{jpg,jpeg,png,webp}', GLOB_BRACE) ?: [];

        $made = 0;
        $io->progressStart(count($photos));
        foreach ($photos as $photo) {
            $made += $this->variants->generate($photo);
            $io->progressAdvance();
        }
        $io->progressFinish();

        $io->success(sprintf('%d photos checked, %d smaller copies made.', count($photos), $made));

        return Command::SUCCESS;
    }
}
