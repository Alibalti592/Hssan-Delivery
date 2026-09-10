<?php

namespace App\Controller\Api;

use App\Dto\Auth\RegisterUserRequest;
use App\Dto\Auth\UserResponse;
use App\Entity\User;
use App\Service\AuthService;
use Symfony\Bundle\SecurityBundle\Security;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/auth')]
class AuthController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly AuthService $authService,
        private readonly Security $security,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('/register', name: 'api_auth_register', methods: ['POST'])]
    public function register(Request $request): JsonResponse
    {
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

    #[Route('/me', name: 'api_auth_me', methods: ['GET'])]
    public function me(): JsonResponse
    {
        /** @var User $user */
        $user = $this->security->getUser();

        return new JsonResponse(UserResponse::fromEntity($user));
    }
}
