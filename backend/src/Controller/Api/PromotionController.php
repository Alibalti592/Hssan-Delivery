<?php

namespace App\Controller\Api;

use App\Dto\Admin\PromotionResponse;
use App\Service\PromotionService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

/**
 * What a signed-in client sees: only promotions that are active and within
 * their validity window right now (see Promotion::isCurrentlyValid) — an
 * expired or deactivated one is never returned, regardless of how it's
 * requested. No #[IsGranted] here — the security.yaml access_control
 * already requires ROLE_USER (any signed-in account) for all non-admin
 * /api routes, matching CatalogueController.
 */
#[Route('/api/promotions')]
final class PromotionController extends AbstractController
{
    public function __construct(
        private readonly PromotionService $promotionService,
    ) {
    }

    #[Route('', name: 'api_promotion_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        $promotions = $this->promotionService->listCurrentlyValid();

        return $this->json(
            array_map(
                static fn ($promotion) => PromotionResponse::fromEntity($promotion),
                $promotions
            )
        );
    }

    #[Route('/{id}', name: 'api_promotion_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $promotion = $this->promotionService->getIfCurrentlyValid($id);

        if (null === $promotion) {
            return $this->json(
                ['message' => 'Promotion not found.'],
                Response::HTTP_NOT_FOUND
            );
        }

        return $this->json(PromotionResponse::fromEntity($promotion));
    }
}
