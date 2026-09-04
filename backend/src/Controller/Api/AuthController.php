<?php

namespace App\Controller\Api;

use App\Dto\RegisterUserRequest;
use App\Dto\UserResponse;
use App\Entity\User;
use App\Repository\UserRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\SecurityBundle\Security;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/auth')]
class AuthController extends AbstractApiController
{
    public function __construct(
        private readonly SerializerInterface $serializer,
        private readonly ValidatorInterface $validator,
        private readonly UserPasswordHasherInterface $passwordHasher,
        private readonly EntityManagerInterface $entityManager,
        private readonly UserRepository $userRepository,
        private readonly Security $security,
    ) {
    }

    #[Route('/register', name: 'api_auth_register', methods: ['POST'])]
    public function register(Request $request): JsonResponse
    {
        /** @var RegisterUserRequest $dto */
        $dto = $this->serializer->deserialize($request->getContent(), RegisterUserRequest::class, 'json');

        $violations = $this->validator->validate($dto);
        if (\count($violations) > 0) {
            return $this->validationErrorResponse($violations);
        }

        if ($this->userRepository->findOneBy(['email' => $dto->email]) !== null) {
            return new JsonResponse(['error' => 'An account with this email already exists.'], Response::HTTP_CONFLICT);
        }

        $user = new User();
        $user->setEmail($dto->email);
        $user->setName($dto->name);
        $user->setPhone($dto->phone);
        $user->setAddress($dto->address);
        $user->setPassword($this->passwordHasher->hashPassword($user, $dto->password));

        if ($dto->accountType === 'LIVREUR') {
            $user->setRoles(['ROLE_LIVREUR']);
            // Livreurs must be approved by an admin before taking deliveries.
            $user->setVerifiedAt(null);
        } else {
            $user->setRoles(['ROLE_CLIENT']);
            $user->setVerifiedAt(new \DateTimeImmutable());
        }

        $this->entityManager->persist($user);
        $this->entityManager->flush();

        return new JsonResponse(UserResponse::fromEntity($user), Response::HTTP_CREATED);
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
