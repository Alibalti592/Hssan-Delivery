<?php

namespace App\Service;

use App\Dto\Admin\CourierLocationResponse;
use App\Entity\CourierLocation;
use App\Entity\Delivery;
use App\Entity\User;
use App\Pagination\Paginator;
use App\Repository\CourierLocationRepository;
use App\Repository\DeliveryRepository;
use App\Repository\UserRepository;
use Doctrine\ORM\EntityManagerInterface;

/**
 * Backs the admin "courier map". There is no continuous GPS tracking in
 * this system — a courier's mobile app reports its position every so often
 * while active, and CourierLocation only ever holds the single latest point
 * per courier (see CourierLocationRepository::findOneByCourier). Everything
 * here is built around that "last known location" reality rather than
 * pretending it's real-time.
 */
final class CourierLocationService
{
    /**
     * A location older than this is treated as stale — the courier is
     * reported OFFLINE even if their account is still flagged available,
     * since their app has stopped reporting for some reason (closed, no
     * signal, permission revoked, etc).
     */
    private const STALE_AFTER_SECONDS = 300;

    public function __construct(
        private readonly EntityManagerInterface $entityManager,
        private readonly CourierLocationRepository $courierLocationRepository,
        private readonly UserRepository $userRepository,
        private readonly DeliveryRepository $deliveryRepository,
    ) {
    }

    public function updateLocation(User $courier, float $latitude, float $longitude): CourierLocation
    {
        $location = $this->courierLocationRepository->findOneByCourier($courier) ?? new CourierLocation();

        $location->setCourier($courier);
        $location->setLatitude($latitude);
        $location->setLongitude($longitude);

        $this->entityManager->persist($location);
        $this->entityManager->flush();

        return $location;
    }

    /**
     * All couriers, each paired with their last known location (if any) and
     * a derived status. Bounded to Paginator::MAX_LIMIT couriers, matching
     * how the rest of the admin API treats "give me everything" at this
     * scale (see CourierService/UserRepository::paginateCouriers).
     *
     * @return array<array<string, mixed>>
     */
    public function listForAdmin(): array
    {
        $couriers = $this->userRepository->paginateCouriers(1, Paginator::MAX_LIMIT)->items;
        $now = new \DateTimeImmutable();

        return array_map(
            function (User $courier) use ($now) {
                $location = $this->courierLocationRepository->findOneByCourier($courier);
                $currentDelivery = $this->deliveryRepository->findActiveForCourier($courier);

                return CourierLocationResponse::fromCourier(
                    $courier,
                    $this->deriveStatus($courier, $location, $currentDelivery, $now),
                    $location?->getLatitude(),
                    $location?->getLongitude(),
                    $location?->getUpdatedAt(),
                    $currentDelivery
                );
            },
            $couriers
        );
    }

    private function deriveStatus(User $courier, ?CourierLocation $location, ?Delivery $currentDelivery, \DateTimeImmutable $now): string
    {
        $isStale = null === $location || ($now->getTimestamp() - $location->getUpdatedAt()->getTimestamp()) > self::STALE_AFTER_SECONDS;

        if ($isStale) {
            return 'OFFLINE';
        }

        if (null !== $currentDelivery) {
            return 'ON_DELIVERY';
        }

        return $courier->isAvailable() ? 'ONLINE' : 'OFFLINE';
    }
}
