<?php

namespace App\Controller\Api;

use App\Dto\Notification\RegisterDeviceTokenRequest;
use App\Dto\Notification\UnregisterDeviceTokenRequest;
use App\Entity\User;
use App\Service\DeviceTokenService;
use Symfony\Bundle\SecurityBundle\Security;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

/**
 * Lets the mobile app register/unregister the current device's FCM token
 * against the signed-in account, so PushNotificationService knows where to
 * send that account's notifications. Any authenticated account can call
 * this (client or courier) — covered by the generic ROLE_USER access rule
 * in security.yaml, same as /api/orders.
 */
#[Route('/api/notifications/device-token')]
final class DeviceTokenController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly DeviceTokenService $deviceTokenService,
        private readonly Security $security,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_device_token_register', methods: ['POST'])]
    public function register(Request $request): JsonResponse
    {
        /** @var RegisterDeviceTokenRequest $dto */
        $dto = $this->deserializeAndValidate($request, RegisterDeviceTokenRequest::class);

        /** @var User $user */
        $user = $this->security->getUser();

        $this->deviceTokenService->register($user, $dto->token, $dto->platform);

        return new JsonResponse(null, Response::HTTP_NO_CONTENT);
    }

    #[Route('', name: 'api_device_token_unregister', methods: ['DELETE'])]
    public function unregister(Request $request): JsonResponse
    {
        /** @var UnregisterDeviceTokenRequest $dto */
        $dto = $this->deserializeAndValidate($request, UnregisterDeviceTokenRequest::class);

        $this->deviceTokenService->unregister($dto->token);

        return new JsonResponse(null, Response::HTTP_NO_CONTENT);
    }
}
