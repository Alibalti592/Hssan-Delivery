<?php

namespace App\Controller\Api;

use App\Dto\Order\CreateBillOrderRequest;
use App\Dto\Order\CreateOrderRequest;
use App\Dto\Order\CreateParcelOrderRequest;
use App\Dto\Order\OrderResponse;
use App\Enum\DeliveryStatus;
use App\Exception\InvalidOperationException;
use App\Repository\CourierLocationRepository;
use App\Repository\OrderRepository;
use App\Service\BillOrderService;
use App\Service\OrderService;
use App\Util\Money;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\ResponseHeaderBag;
use Symfony\Component\RateLimiter\RateLimiterFactory;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/orders')]
final class OrderController extends AbstractApiController
{
    use PaginationParamsTrait;

    public function __construct(
        private readonly OrderService $orderService,
        private readonly RateLimiterFactory $orderCreateLimiter,
        private readonly BillOrderService $billOrderService,
        private readonly OrderRepository $orderRepository,
        private readonly CourierLocationRepository $courierLocationRepository,
        SerializerInterface $serializer,
        ValidatorInterface $validator,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_orders_list', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $result = $this->orderService->getUserOrders(
            $user,
            $this->paginationPage($request),
            $this->paginationLimit($request)
        );

        return $this->paginatedJson($result, static fn (\App\Entity\Order $order) => OrderResponse::fromEntity($order));
    }

    #[Route('/{id}', name: 'api_orders_show', methods: ['GET'], requirements: ['id' => '\d+'])]
    public function show(int $id): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $order = $this->orderService->getUserOrder($id, $user);

        if (null === $order) {
            return $this->json(
                ['message' => 'Commande introuvable.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(
            OrderResponse::fromEntity($order)
        );
    }

    #[Route('', name: 'api_orders_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $limiter = $this->orderCreateLimiter->create((string) $user->getId());

        if (!$limiter->consume()->isAccepted()) {
            return $this->json(
                ['message' => 'Trop de tentatives. Réessayez plus tard.'],
                Response::HTTP_TOO_MANY_REQUESTS
            );
        }

        /** @var CreateOrderRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateOrderRequest::class);

        $order = $this->orderService->createOrder($dto, $user);

        return $this->json(
            OrderResponse::fromEntity($order),
            Response::HTTP_CREATED
        );
    }

    /**
     * The checkout's live total: what POST /api/orders would charge for this
     * cart, address and promo code, without placing the order. Same checks
     * and same messages as placing it.
     */
    #[Route('/quote', name: 'api_orders_quote', methods: ['POST'])]
    public function quote(Request $request): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        /** @var CreateOrderRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateOrderRequest::class);

        $order = $this->orderService->quoteOrder($dto, $user);

        $total = Money::toMillimes($order->getTotalAmount());
        $fee = Money::toMillimes($order->getDeliveryFee());
        $discount = Money::toMillimes($order->getDiscountAmount());

        return $this->json([
            'subtotal' => Money::fromMillimes($total - $fee + $discount),
            'discountAmount' => $order->getDiscountAmount(),
            'deliveryFee' => $order->getDeliveryFee(),
            'totalAmount' => $order->getTotalAmount(),
            'promotionTitle' => $order->getPromotionTitle(),
            'promoCode' => $order->getPromoCode(),
        ]);
    }

    #[Route('/parcels', name: 'api_orders_create_parcel', methods: ['POST'])]
    public function createParcel(Request $request): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $limiter = $this->orderCreateLimiter->create((string) $user->getId());

        if (!$limiter->consume()->isAccepted()) {
            return $this->json(
                ['message' => 'Trop de tentatives. Réessayez plus tard.'],
                Response::HTTP_TOO_MANY_REQUESTS
            );
        }

        /** @var CreateParcelOrderRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateParcelOrderRequest::class);

        $order = $this->orderService->createParcelOrder($dto, $user);

        return $this->json(
            OrderResponse::fromEntity($order),
            Response::HTTP_CREATED
        );
    }

    #[Route('/bills', name: 'api_orders_create_bill', methods: ['POST'])]
    public function createBill(Request $request): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $limiter = $this->orderCreateLimiter->create((string) $user->getId());

        if (!$limiter->consume()->isAccepted()) {
            return $this->json(
                ['message' => 'Trop de tentatives. Réessayez plus tard.'],
                Response::HTTP_TOO_MANY_REQUESTS
            );
        }

        /** @var CreateBillOrderRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateBillOrderRequest::class);

        $order = $this->billOrderService->createBillOrder($dto, $user);

        return $this->json(
            OrderResponse::fromEntity($order),
            Response::HTTP_CREATED
        );
    }

    /**
     * The client attaches a photo of their bill to a Factures order they
     * just placed (multipart, field "photo").
     */
    #[Route('/{id}/bill-photo', name: 'api_orders_bill_photo_upload', methods: ['POST'], requirements: ['id' => '\d+'])]
    public function uploadBillPhoto(int $id, Request $request): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $order = $this->orderService->getUserOrder($id, $user);

        if (null === $order) {
            return $this->json(
                ['message' => 'Commande introuvable.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $file = $request->files->get('photo');

        if (null === $file) {
            throw new InvalidOperationException('Aucune photo n\'a été envoyée.');
        }

        $order = $this->billOrderService->setBillPhoto($order, $file);

        return $this->json(
            OrderResponse::fromEntity($order)
        );
    }

    /**
     * The bill photo itself, for the client who took it, the courier doing
     * the job and admins only — it never sits under the public /uploads.
     */
    #[Route('/{id}/bill-photo', name: 'api_orders_bill_photo_show', methods: ['GET'], requirements: ['id' => '\d+'])]
    public function billPhoto(int $id): Response
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $order = $this->orderRepository->find($id);
        $path = null === $order ? null : $this->billOrderService->billPhotoPath($order);

        // Same answer whether the order doesn't exist, has no photo, or
        // isn't this user's to see.
        if (null === $order || null === $path || !$this->billOrderService->canViewBillPhoto($order, $user)) {
            return $this->json(
                ['message' => 'Photo introuvable.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $response = new BinaryFileResponse($path);
        $response->setPrivate();
        $response->setMaxAge(3600);
        $response->setContentDisposition(ResponseHeaderBag::DISPOSITION_INLINE, 'facture-'.$order->getId().'.'.pathinfo($path, PATHINFO_EXTENSION));

        return $response;
    }

    /**
     * Where the courier is, for the client following their order on the
     * map ("Suivre ma commande"): their last reported position, only while
     * they're actually on this order (accepted it, until it's delivered).
     * 404 otherwise — before a courier accepts, after delivery, or while
     * their app hasn't reported a position yet.
     */
    #[Route('/{id}/courier-location', name: 'api_orders_courier_location', methods: ['GET'], requirements: ['id' => '\d+'])]
    public function courierLocation(int $id): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $delivery = $this->orderService->getUserOrder($id, $user)?->getDelivery();
        $courier = $delivery?->getCourier();
        $onTheJob = \in_array($delivery?->getStatus(), [
            DeliveryStatus::ACCEPTED,
            DeliveryStatus::PICKED_UP,
            DeliveryStatus::ON_THE_WAY,
        ], true);
        $location = $onTheJob && null !== $courier
            ? $this->courierLocationRepository->findOneByCourier($courier)
            : null;

        if (null === $location) {
            return $this->json(
                ['message' => 'Position du livreur indisponible.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json([
            'latitude' => $location->getLatitude(),
            'longitude' => $location->getLongitude(),
            'updatedAt' => $location->getUpdatedAt()?->format(\DateTimeInterface::ATOM),
        ]);
    }

    #[Route('/{id}/cancel', name: 'api_orders_cancel', methods: ['POST'], requirements: ['id' => '\d+'])]
    public function cancel(int $id): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof \App\Entity\User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $order = $this->orderService->getUserOrder($id, $user);

        if (null === $order) {
            return $this->json(
                ['message' => 'Commande introuvable.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $order = $this->orderService->cancelOrder($order);

        return $this->json(
            OrderResponse::fromEntity($order)
        );
    }
}
