<?php

namespace App\Controller\Api;

use App\Dto\Address\AddressResponse;
use App\Dto\Address\CreateAddressRequest;
use App\Dto\Address\UpdateAddressRequest;
use App\Entity\User;
use App\Service\AddressService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/addresses')]
final class AddressController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly AddressService $addressService,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_addresses_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        /** @var CreateAddressRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreateAddressRequest::class);

        $address = $this->addressService->create($user, $dto);

        return $this->json(
            AddressResponse::fromEntity($address),
            Response::HTTP_CREATED
        );
    }

    #[Route('', name: 'api_addresses_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $addresses = $this->addressService->listForUser($user);

        return $this->json(
            array_map(
                static fn ($address) => AddressResponse::fromEntity($address),
                $addresses
            )
        );
    }

    #[Route('/{id}', name: 'api_addresses_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $address = $this->addressService->get($id, $user);

        if (null === $address) {
            return $this->json(
                ['message' => 'Address not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(
            AddressResponse::fromEntity($address)
        );
    }

    #[Route('/{id}', name: 'api_addresses_update', methods: ['PUT'])]
    public function update(
        int $id,
        Request $request,
    ): JsonResponse {
        $user = $this->getUser();

        if (!$user instanceof User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $address = $this->addressService->get($id, $user);

        if (null === $address) {
            return $this->json(
                ['message' => 'Address not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        /** @var UpdateAddressRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateAddressRequest::class);

        $address = $this->addressService->update($address, $dto);

        return $this->json(
            AddressResponse::fromEntity($address)
        );
    }

    #[Route('/{id}', name: 'api_addresses_delete', methods: ['DELETE'])]
    public function delete(int $id): JsonResponse
    {
        $user = $this->getUser();

        if (!$user instanceof User) {
            return $this->json(
                ['message' => 'Authentication required.'],
                Response::HTTP_UNAUTHORIZED
            );
        }

        $address = $this->addressService->get($id, $user);

        if (null === $address) {
            return $this->json(
                ['message' => 'Address not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        $this->addressService->delete($address);

        return $this->json(null, Response::HTTP_NO_CONTENT);
    }
}
