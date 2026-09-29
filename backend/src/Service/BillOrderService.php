<?php

namespace App\Service;

use App\Dto\Order\CreateBillOrderRequest;
use App\Entity\Delivery;
use App\Entity\Order;
use App\Entity\User;
use App\Enum\BillProviderKind;
use App\Enum\DeliveryStatus;
use App\Enum\DeliveryType;
use App\Enum\OrderStatus;
use App\Exception\InvalidOperationException;
use App\Exception\ValidationFailedException;
use App\Repository\BillProviderRepository;
use App\Repository\DeliveryZoneRepository;
use App\Util\Money;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpFoundation\File\UploadedFile;

/**
 * Factures orders: a courier collects cash (and the bill, if there is one)
 * at the client's address, pays at the provider's counter — a bill, or a
 * mandat sent through IZI/Wafa Cash — and brings the receipt back. Priced
 * like every other service, off the delivery zone's flat fee; the order's
 * total is the cash the client hands over (amount + fee).
 */
final class BillOrderService
{
    /**
     * The most cash a courier is asked to carry for one order.
     */
    public const MAX_AMOUNT = '2000.000';

    public const PHOTO_SUBDIRECTORY = 'bills';

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly BillProviderRepository $billProviderRepository,
        private readonly DeliveryZoneRepository $deliveryZoneRepository,
        #[Autowire(service: 'app.private_photo_uploader')]
        private readonly PhotoUploader $privatePhotoUploader,
    ) {
    }

    public function createBillOrder(CreateBillOrderRequest $dto, User $user): Order
    {
        $provider = $this->billProviderRepository->find($dto->providerId);

        if (null === $provider || !$provider->isActive()) {
            throw new InvalidOperationException('Bill provider not found.');
        }

        $deliveryZone = $this->deliveryZoneRepository->find($dto->deliveryZoneId);

        if (null === $deliveryZone) {
            throw new InvalidOperationException('Delivery zone not found.');
        }

        $amountMillimes = Money::toMillimes((string) $dto->amount);
        $reference = $this->blankToNull($dto->reference);
        $recipientName = $this->blankToNull($dto->recipientName);
        $recipientPhone = $this->blankToNull($dto->recipientPhone);

        $errors = [];

        if ($amountMillimes <= 0) {
            $errors[] = ['field' => 'amount', 'message' => 'Amount must be greater than zero.'];
        } elseif ($amountMillimes > Money::toMillimes(self::MAX_AMOUNT)) {
            $errors[] = ['field' => 'amount', 'message' => sprintf('Amount cannot exceed %s DT.', rtrim(rtrim(self::MAX_AMOUNT, '0'), '.'))];
        }

        if (BillProviderKind::BILL === $provider->getKind()) {
            if (null === $reference) {
                $errors[] = ['field' => 'reference', 'message' => 'The bill reference is required.'];
            }
            // A bill is paid to the provider: nobody else receives anything.
            $recipientName = null;
            $recipientPhone = null;
        } else {
            if (null === $recipientName) {
                $errors[] = ['field' => 'recipientName', 'message' => 'The recipient\'s name is required.'];
            }
            if (null === $recipientPhone) {
                $errors[] = ['field' => 'recipientPhone', 'message' => 'The recipient\'s phone is required.'];
            }
            $reference = null;
        }

        if ([] !== $errors) {
            throw new ValidationFailedException($errors);
        }

        $order = new Order();

        $order->setUser($user);
        $order->setDeliveryType(DeliveryType::BILL);
        $order->setBillProvider($provider);
        $order->setBillReference($reference);
        $order->setBillAmount(Money::fromMillimes($amountMillimes));
        $order->setRecipientName($recipientName);
        $order->setRecipientPhone($recipientPhone);
        // The courier starts and ends at the client: cash out, receipt back.
        $order->setPickupAddress($dto->address);
        $order->setDeliveryAddress($dto->address);
        $order->setNote($this->blankToNull($dto->note));
        $order->setDeliveryZone($deliveryZone);
        // Collected and returned at the same spot.
        $order->setDeliveryLocation($dto->deliveryLatitude, $dto->deliveryLongitude);
        $order->setPickupLocation($dto->deliveryLatitude, $dto->deliveryLongitude);
        $order->setStatus(OrderStatus::PENDING);

        $feeMillimes = Money::toMillimes($deliveryZone->getFee());

        $order->setDeliveryFee(Money::fromMillimes($feeMillimes));
        $order->setTotalAmount(Money::fromMillimes($amountMillimes + $feeMillimes));

        $delivery = new Delivery();

        $delivery->setOrder($order);
        $delivery->setStatus(DeliveryStatus::PENDING);

        $order->setDelivery($delivery);

        $this->entityManager->persist($delivery);
        $this->entityManager->persist($order);
        $this->entityManager->flush();

        return $order;
    }

    /**
     * Attaches (or replaces) the client's photo of their bill, until a
     * courier has set off with it.
     */
    public function setBillPhoto(Order $order, UploadedFile $file): Order
    {
        if (DeliveryType::BILL !== $order->getDeliveryType()) {
            throw new InvalidOperationException('Only a bill order can have a bill photo.');
        }

        $deliveryStatus = $order->getDelivery()?->getStatus();

        if (!in_array($deliveryStatus, [DeliveryStatus::PENDING, DeliveryStatus::ASSIGNED], true)) {
            throw new InvalidOperationException('The bill photo can no longer be changed.');
        }

        $filename = $this->privatePhotoUploader->store($file, self::PHOTO_SUBDIRECTORY);

        $this->privatePhotoUploader->delete($order->getBillPhotoFilename(), self::PHOTO_SUBDIRECTORY);

        $order->setBillPhotoFilename($filename);

        $this->entityManager->flush();

        return $order;
    }

    /**
     * Who may see a bill photo: the client who took it, the courier doing
     * the job, and admins.
     */
    public function canViewBillPhoto(Order $order, User $user): bool
    {
        return in_array('ROLE_ADMIN', $user->getRoles(), true)
            || $order->getUser() === $user
            || (null !== $order->getDelivery()?->getCourier() && $order->getDelivery()->getCourier() === $user);
    }

    public function billPhotoPath(Order $order): ?string
    {
        return $this->privatePhotoUploader->path($order->getBillPhotoFilename(), self::PHOTO_SUBDIRECTORY);
    }

    public static function billPhotoUrl(Order $order): ?string
    {
        return null === $order->getBillPhotoFilename()
            ? null
            : sprintf('/api/orders/%d/bill-photo', $order->getId());
    }

    private function blankToNull(?string $value): ?string
    {
        $value = null === $value ? null : trim($value);

        return '' === $value ? null : $value;
    }
}
