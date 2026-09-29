<?php

namespace App\Dto\Admin;

use App\Entity\BillProvider;
use App\Service\BillProviderService;
use App\Service\PhotoUploader;

final class BillProviderResponse
{
    public static function fromEntity(BillProvider $provider): array
    {
        return [
            'id' => $provider->getId(),
            'name' => $provider->getName(),
            'kind' => $provider->getKind()->value,
            'logoUrl' => PhotoUploader::url($provider->getLogoFilename(), BillProviderService::LOGO_SUBDIRECTORY),
            'isActive' => $provider->isActive(),
            'position' => $provider->getPosition(),
        ];
    }
}
