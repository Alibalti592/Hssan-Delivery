<?php

namespace App\Service;

use App\Dto\Admin\BillProviderRequest;
use App\Entity\BillProvider;
use App\Enum\BillProviderKind;
use App\Exception\ConflictException;
use App\Repository\BillProviderRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\File\UploadedFile;

final class BillProviderService
{
    public const LOGO_SUBDIRECTORY = 'bill-providers';

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly BillProviderRepository $billProviderRepository,
        private readonly PhotoUploader $photoUploader,
    ) {
    }

    /**
     * @return BillProvider[]
     */
    public function list(): array
    {
        return $this->billProviderRepository->findAllOrdered();
    }

    /**
     * What the client can pick on the Factures screen.
     *
     * @return BillProvider[]
     */
    public function listActive(): array
    {
        return $this->billProviderRepository->findAllOrdered(activeOnly: true);
    }

    public function get(int $id): ?BillProvider
    {
        return $this->billProviderRepository->find($id);
    }

    public function create(BillProviderRequest $dto): BillProvider
    {
        $provider = new BillProvider();

        $this->apply($provider, $dto);

        $this->entityManager->persist($provider);
        $this->entityManager->flush();

        return $provider;
    }

    public function update(BillProvider $provider, BillProviderRequest $dto): BillProvider
    {
        $this->apply($provider, $dto);

        $this->entityManager->flush();

        return $provider;
    }

    public function setActive(BillProvider $provider, bool $isActive): BillProvider
    {
        $provider->setIsActive($isActive);

        $this->entityManager->flush();

        return $provider;
    }

    public function setLogo(BillProvider $provider, UploadedFile $file): BillProvider
    {
        $filename = $this->photoUploader->store($file, self::LOGO_SUBDIRECTORY);

        $this->photoUploader->delete($provider->getLogoFilename(), self::LOGO_SUBDIRECTORY);

        $provider->setLogoFilename($filename);

        $this->entityManager->flush();

        return $provider;
    }

    public function removeLogo(BillProvider $provider): BillProvider
    {
        $this->photoUploader->delete($provider->getLogoFilename(), self::LOGO_SUBDIRECTORY);

        $provider->setLogoFilename(null);

        $this->entityManager->flush();

        return $provider;
    }

    private function apply(BillProvider $provider, BillProviderRequest $dto): void
    {
        $name = trim((string) $dto->name);

        $existing = $this->billProviderRepository->findOneBy(['name' => $name]);

        if (null !== $existing && $existing !== $provider) {
            throw new ConflictException('A bill provider with this name already exists.');
        }

        $provider->setName($name);
        $provider->setKind(BillProviderKind::from((string) $dto->kind));
        $provider->setPosition((int) $dto->position);
    }
}
