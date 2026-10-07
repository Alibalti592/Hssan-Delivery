<?php

namespace App\Controller\Api;

use App\Dto\Admin\ResetUserPasswordRequest;
use App\Enum\UserRole;
use App\Repository\UserRepository;
use App\Service\PasswordResetService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/admin/users')]
#[IsGranted('ROLE_ADMIN')]
final class AdminUserController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly UserRepository $userRepository,
        private readonly PasswordResetService $passwordReset,
    ) {
        parent::__construct($serializer, $validator);
    }

    /**
     * "Mot de passe oublié": the client writes to support on WhatsApp, and
     * the admin sets a new password for that phone number here and sends
     * it back. Clients and couriers only — an admin changes their own
     * password from their account.
     */
    #[Route('/password', name: 'api_admin_user_reset_password', methods: ['PATCH'])]
    public function resetPassword(Request $request): JsonResponse
    {
        /** @var ResetUserPasswordRequest $dto */
        $dto = $this->deserializeAndValidate($request, ResetUserPasswordRequest::class);

        $user = $this->userRepository->findOneByPhone($dto->phone);

        if (null === $user) {
            return $this->json(
                ['message' => 'Aucun compte avec ce numéro.'],
                Response::HTTP_NOT_FOUND
            );
        }

        if (\in_array(UserRole::ADMIN->value, $user->getRoles(), true)) {
            return $this->json(
                ['message' => 'Le mot de passe d\'un administrateur se change depuis son propre compte.'],
                Response::HTTP_FORBIDDEN
            );
        }

        $this->passwordReset->reset($user, $dto->password);

        return $this->json([
            'id' => $user->getId(),
            'name' => $user->getName(),
            'phone' => $user->getPhone(),
            'role' => \in_array(UserRole::LIVREUR->value, $user->getRoles(), true)
                ? 'COURIER'
                : 'CLIENT',
        ]);
    }
}
