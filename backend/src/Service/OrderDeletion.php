<?php

namespace App\Service;

use App\Entity\Order;
use App\Enum\OrderStatus;
use App\Exception\InvalidOperationException;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

/**
 * The admin deleting an order for good (a test order, a mistake): its
 * lines, its delivery and its bill photo go with it, and it leaves the
 * customer's and the courier's history, the sales and the popularity.
 *
 * Only once it's over (delivered or cancelled): one still on its way is
 * cancelled first, so no courier is left heading to a job that's gone.
 */
final class OrderDeletion
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        #[Autowire(service: 'app.private_photo_uploader')]
        private readonly PhotoUploader $privatePhotoUploader,
    ) {
    }

    /**
     * @throws InvalidOperationException when the order isn't over yet
     */
    public function delete(Order $order): void
    {
        if (!in_array($order->getStatus(), [OrderStatus::COMPLETED, OrderStatus::CANCELLED], true)) {
            throw new InvalidOperationException('Only a delivered or cancelled order can be deleted. Cancel it first.');
        }

        $billPhoto = $order->getBillPhotoFilename();

        if (null !== $delivery = $order->getDelivery()) {
            $this->entityManager->remove($delivery);
        }
        foreach ($order->getItems() as $item) {
            $this->entityManager->remove($item);
        }
        $this->entityManager->remove($order);
        $this->entityManager->flush();

        // Once the order is gone for sure: a failed flush keeps the photo.
        $this->privatePhotoUploader->delete($billPhoto, BillOrderService::PHOTO_SUBDIRECTORY);
    }
}
