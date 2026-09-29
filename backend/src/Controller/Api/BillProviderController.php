<?php

namespace App\Controller\Api;

use App\Dto\Admin\BillProviderResponse;
use App\Service\BillProviderService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;

/**
 * The providers a client can pick on the Factures screen — hidden ones are
 * left out. Signed-in access only, through security.yaml's access_control,
 * like the catalogue.
 */
#[Route('/api/bill-providers')]
final class BillProviderController extends AbstractController
{
    public function __construct(
        private readonly BillProviderService $billProviderService,
    ) {
    }

    #[Route('', name: 'api_bill_provider_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        return $this->json(array_map(
            static fn ($provider) => BillProviderResponse::fromEntity($provider),
            $this->billProviderService->listActive()
        ));
    }
}
