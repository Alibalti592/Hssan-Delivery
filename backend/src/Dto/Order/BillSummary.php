<?php

namespace App\Dto\Order;

use App\Entity\Order;
use App\Service\BillOrderService;
use App\Service\BillProviderService;
use App\Service\PhotoUploader;

/**
 * The Factures part of an order, as the client, the courier and the admin
 * all see it; null for every other service. A mandat's receiver is in the
 * order's recipientName/recipientPhone.
 */
final class BillSummary
{
    /**
     * @return array<string, mixed>|null
     */
    public static function of(Order $order): ?array
    {
        $provider = $order->getBillProvider();

        if (null === $provider) {
            return null;
        }

        return [
            'providerId' => $provider->getId(),
            'providerName' => $provider->getName(),
            'providerKind' => $provider->getKind()->value,
            'providerLogoUrl' => PhotoUploader::url($provider->getLogoFilename(), BillProviderService::LOGO_SUBDIRECTORY),
            'reference' => $order->getBillReference(),
            'amount' => $order->getBillAmount(),
            'photoUrl' => BillOrderService::billPhotoUrl($order),
        ];
    }
}
