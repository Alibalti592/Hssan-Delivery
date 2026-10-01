<?php

namespace App\Controller\Api;

use App\Dto\Auth\ChangePasswordRequest;
use App\Dto\Auth\DeleteAccountRequest;
use App\Dto\Auth\RegisterUserRequest;
use App\Dto\Auth\UpdateAvailabilityRequest;
use App\Dto\Auth\UserResponse;
use App\Entity\User;
use App\Security\RefreshCookie;
use App\Service\AccountDeletionService;
use App\Service\AuthService;
use App\Service\RefreshTokenService;
use Lexik\Bundle\JWTAuthenticationBundle\Security\Http\Cookie\JWTCookieProvider;
use Symfony\Bundle\SecurityBundle\Security;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpFoundation\Cookie;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\RateLimiter\RateLimiterFactory;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/auth')]
class AuthController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly AuthService $authService,
        private readonly RefreshTokenService $refreshTokens,
        private readonly AccountDeletionService $accountDeletion,
        private readonly RefreshCookie $refreshCookie,
        #[Autowire(service: 'lexik_jwt_authentication.cookie_provider.BEARER')]
        private readonly JWTCookieProvider $bearerCookie,
        private readonly Security $security,
        private readonly RateLimiterFactory $registerLimiter,
        private readonly RateLimiterFactory $passwordChangeLimiter,
        private readonly bool $jwtCookieSecure,
        private readonly string $jwtCookieSameSite,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('/register', name: 'api_auth_register', methods: ['POST'])]
    public function register(Request $request): JsonResponse
    {
        $limiter = $this->registerLimiter->create($request->getClientIp());

        if (!$limiter->consume()->isAccepted()) {
            return new JsonResponse(
                ['message' => 'Trop de tentatives. Réessayez plus tard.'],
                Response::HTTP_TOO_MANY_REQUESTS
            );
        }

        /** @var RegisterUserRequest $dto */
        $dto = $this->deserializeAndValidate($request, RegisterUserRequest::class);

        $user = $this->authService->register($dto);

        return new JsonResponse(
            UserResponse::fromEntity($user),
            Response::HTTP_CREATED
        );
    }

    /**
     * Never actually executed: the "api_login" firewall's json_login
     * authenticator intercepts POST /api/auth/login before the router
     * dispatches to a controller. This route only needs to exist so the
     * router doesn't 404 before the firewall gets a chance to run.
     */
    #[Route('/login', name: 'api_auth_login', methods: ['POST'])]
    public function login(): never
    {
        throw new \LogicException('This route is handled by the json_login authenticator and should never execute.');
    }

    /**
     * Clears the admin dashboard's httpOnly auth cookie. Mobile clients
     * never receive that cookie in the first place (they authenticate via
     * the Authorization header), so this is a no-op for them — they just
     * stop sending the header locally. There's nothing else to invalidate
     * server-side for a stateless JWT: the token itself stays technically
     * valid until it expires, this only removes the browser's copy of it.
     */
    /**
     * Trades a refresh token for a new session (see RefreshTokenService).
     * The mobile app sends it in the body and gets the new tokens back in
     * the body; the admin dashboard's comes and goes as httpOnly cookies.
     * Outside the JWT firewall: the session it replaces has usually expired.
     */
    #[Route('/refresh', name: 'api_auth_refresh', methods: ['POST'])]
    public function refresh(Request $request): JsonResponse
    {
        $fromBody = self::refreshTokenFrom($request);
        $tokens = $this->refreshTokens->refresh($fromBody ?? RefreshCookie::from($request) ?? '');

        if (null === $tokens) {
            $response = new JsonResponse(
                ['message' => 'Session expirée. Reconnectez-vous.'],
                Response::HTTP_UNAUTHORIZED
            );
            if (null === $fromBody) {
                $response->headers->setCookie($this->refreshCookie->clear());
            }

            return $response;
        }

        if (null !== $fromBody) {
            return new JsonResponse($tokens);
        }

        $response = new JsonResponse(null, Response::HTTP_NO_CONTENT);
        $response->headers->setCookie($this->bearerCookie->createCookie($tokens['token']));
        $response->headers->setCookie($this->refreshCookie->create($tokens['refreshToken']));

        return $response;
    }

    /**
     * Public, like refresh: the app signs out with its refresh token, which
     * stops working, whether or not its JWT is still valid.
     */
    #[Route('/logout', name: 'api_auth_logout', methods: ['POST'])]
    public function logout(Request $request): JsonResponse
    {
        $refreshToken = self::refreshTokenFrom($request) ?? RefreshCookie::from($request);
        if (null !== $refreshToken) {
            $this->refreshTokens->revoke($refreshToken);
        }

        $response = new JsonResponse(null, Response::HTTP_NO_CONTENT);

        $response->headers->clearCookie(
            'BEARER',
            '/',
            null,
            $this->jwtCookieSecure,
            true,
            $this->jwtCookieSameSite
        );
        $response->headers->setCookie($this->refreshCookie->clear());

        return $response;
    }

    #[Route('/me', name: 'api_auth_me', methods: ['GET'])]
    public function me(): JsonResponse
    {
        /** @var User $user */
        $user = $this->security->getUser();

        return new JsonResponse(UserResponse::fromEntity($user));
    }

    /**
     * "Supprimer mon compte" (see AccountDeletionService): asks for the
     * password again, and refuses while an order is in progress.
     */
    #[Route('/me', name: 'api_auth_delete_account', methods: ['DELETE'])]
    public function deleteAccount(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $this->security->getUser();

        $limiter = $this->passwordChangeLimiter->create((string) $user->getId());
        if (!$limiter->consume()->isAccepted()) {
            return new JsonResponse(
                ['message' => 'Trop de tentatives. Réessayez plus tard.'],
                Response::HTTP_TOO_MANY_REQUESTS
            );
        }

        /** @var DeleteAccountRequest $dto */
        $dto = $this->deserializeAndValidate($request, DeleteAccountRequest::class);

        $this->accountDeletion->delete($user, $dto->password);

        return new JsonResponse(null, Response::HTTP_NO_CONTENT);
    }

    /**
     * Self-service password change. Requires the current password, so this
     * covers "I know my password but want to change it" — not account
     * recovery for a locked-out user (there's no email/SMS channel in this
     * app to verify identity through; see AdminCourierController::resetPassword()
     * for how couriers recover access instead).
     */
    #[Route('/change-password', name: 'api_auth_change_password', methods: ['POST'])]
    public function changePassword(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $this->security->getUser();

        $limiter = $this->passwordChangeLimiter->create((string) $user->getId());

        if (!$limiter->consume()->isAccepted()) {
            return new JsonResponse(
                ['message' => 'Trop de tentatives. Réessayez plus tard.'],
                Response::HTTP_TOO_MANY_REQUESTS
            );
        }

        /** @var ChangePasswordRequest $dto */
        $dto = $this->deserializeAndValidate($request, ChangePasswordRequest::class);

        $this->authService->changePassword($user, $dto->currentPassword, $dto->newPassword);
        // Every other device has to sign in with the new password; this one
        // (when it sent its refresh token) stays signed in.
        $this->refreshTokens->revokeAll($user, $dto->refreshToken);

        return new JsonResponse(null, Response::HTTP_NO_CONTENT);
    }

    /**
     * Self-service toggle for a courier's own availability — distinct from
     * AdminCourierController::active(), which is an admin deactivating the
     * account entirely, not the courier stepping away for a break.
     */
    #[Route('/availability', name: 'api_auth_availability', methods: ['PATCH'])]
    #[IsGranted('ROLE_LIVREUR')]
    public function availability(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $this->security->getUser();

        /** @var UpdateAvailabilityRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateAvailabilityRequest::class);

        $this->authService->setAvailability($user, $dto->isAvailable);

        return new JsonResponse(UserResponse::fromEntity($user));
    }

    private static function refreshTokenFrom(Request $request): ?string
    {
        $body = json_decode($request->getContent(), true);
        $token = \is_array($body) ? ($body['refreshToken'] ?? null) : null;

        return \is_string($token) && '' !== $token ? $token : null;
    }
}
