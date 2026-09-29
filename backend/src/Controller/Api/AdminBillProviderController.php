<?php

namespace App\Controller\Api;

use App\Dto\Admin\BillProviderRequest;
use App\Dto\Admin\BillProviderResponse;
use App\Dto\Admin\UpdateBillProviderActiveRequest;
use App\Exception\InvalidOperationException;
use App\Service\BillProviderService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

/**
 * The providers offered on the client's Factures screen. There is no
 * delete: past orders point at their provider, so one is hidden instead.
 */
#[Route('/api/admin/bill-providers')]
#[IsGranted('ROLE_ADMIN')]
final class AdminBillProviderController extends AbstractApiController
{
    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly BillProviderService $billProviderService,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_admin_bill_provider_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        return $this->json(array_map(
            static fn ($provider) => BillProviderResponse::fromEntity($provider),
            $this->billProviderService->list()
        ));
    }

    #[Route('', name: 'api_admin_bill_provider_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        /** @var BillProviderRequest $dto */
        $dto = $this->deserializeAndValidate($request, BillProviderRequest::class);

        return $this->json(
            BillProviderResponse::fromEntity($this->billProviderService->create($dto)),
            Response::HTTP_CREATED
        );
    }

    #[Route('/{id}', name: 'api_admin_bill_provider_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $provider = $this->billProviderService->get($id);

        if (null === $provider) {
            return $this->providerNotFound();
        }

        return $this->json(BillProviderResponse::fromEntity($provider));
    }

    #[Route('/{id}', name: 'api_admin_bill_provider_update', methods: ['PUT'])]
    public function update(int $id, Request $request): JsonResponse
    {
        $provider = $this->billProviderService->get($id);

        if (null === $provider) {
            return $this->providerNotFound();
        }

        /** @var BillProviderRequest $dto */
        $dto = $this->deserializeAndValidate($request, BillProviderRequest::class);

        return $this->json(
            BillProviderResponse::fromEntity($this->billProviderService->update($provider, $dto))
        );
    }

    #[Route('/{id}/active', name: 'api_admin_bill_provider_active', methods: ['PATCH'])]
    public function setActive(int $id, Request $request): JsonResponse
    {
        $provider = $this->billProviderService->get($id);

        if (null === $provider) {
            return $this->providerNotFound();
        }

        /** @var UpdateBillProviderActiveRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdateBillProviderActiveRequest::class);

        return $this->json(
            BillProviderResponse::fromEntity($this->billProviderService->setActive($provider, (bool) $dto->isActive))
        );
    }

    #[Route('/{id}/logo', name: 'api_admin_bill_provider_logo_upload', methods: ['POST'])]
    public function uploadLogo(int $id, Request $request): JsonResponse
    {
        $provider = $this->billProviderService->get($id);

        if (null === $provider) {
            return $this->providerNotFound();
        }

        $file = $request->files->get('logo');

        if (null === $file) {
            throw new InvalidOperationException('No logo was uploaded.');
        }

        return $this->json(
            BillProviderResponse::fromEntity($this->billProviderService->setLogo($provider, $file))
        );
    }

    #[Route('/{id}/logo', name: 'api_admin_bill_provider_logo_remove', methods: ['DELETE'])]
    public function removeLogo(int $id): JsonResponse
    {
        $provider = $this->billProviderService->get($id);

        if (null === $provider) {
            return $this->providerNotFound();
        }

        return $this->json(
            BillProviderResponse::fromEntity($this->billProviderService->removeLogo($provider))
        );
    }

    private function providerNotFound(): JsonResponse
    {
        return $this->json(
            ['message' => 'Bill provider not found.'],
            Response::HTTP_NOT_FOUND
        );
    }
}
