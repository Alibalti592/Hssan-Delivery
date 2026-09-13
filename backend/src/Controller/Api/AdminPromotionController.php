<?php

namespace App\Controller\Api;

use App\Dto\Admin\CreatePromotionRequest;
use App\Dto\Admin\PromotionResponse;
use App\Dto\Admin\UpdatePromotionActiveRequest;
use App\Dto\Admin\UpdatePromotionRequest;
use App\Exception\InvalidOperationException;
use App\Service\PromotionService;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api/admin/promotions')]
#[IsGranted('ROLE_ADMIN')]
final class AdminPromotionController extends AbstractApiController
{
    use PaginationParamsTrait;

    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly PromotionService $promotionService,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_admin_promotion_create', methods: ['POST'])]
    public function create(Request $request): JsonResponse
    {
        /** @var CreatePromotionRequest $dto */
        $dto = $this->deserializeAndValidate($request, CreatePromotionRequest::class);

        $promotion = $this->promotionService->create($dto);

        return $this->json(
            PromotionResponse::fromEntity($promotion),
            Response::HTTP_CREATED
        );
    }

    #[Route('', name: 'api_admin_promotion_list', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        $result = $this->promotionService->list(
            $this->paginationPage($request),
            $this->paginationLimit($request)
        );

        return $this->paginatedJson($result, static fn ($promotion) => PromotionResponse::fromEntity($promotion));
    }

    #[Route('/{id}', name: 'api_admin_promotion_show', methods: ['GET'])]
    public function show(int $id): JsonResponse
    {
        $promotion = $this->promotionService->get($id);

        if (null === $promotion) {
            return $this->promotionNotFound();
        }

        return $this->json(PromotionResponse::fromEntity($promotion));
    }

    #[Route('/{id}', name: 'api_admin_promotion_update', methods: ['PUT'])]
    public function update(int $id, Request $request): JsonResponse
    {
        $promotion = $this->promotionService->get($id);

        if (null === $promotion) {
            return $this->promotionNotFound();
        }

        /** @var UpdatePromotionRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdatePromotionRequest::class);

        $promotion = $this->promotionService->update($promotion, $dto);

        return $this->json(PromotionResponse::fromEntity($promotion));
    }

    #[Route('/{id}', name: 'api_admin_promotion_delete', methods: ['DELETE'])]
    public function delete(int $id): JsonResponse
    {
        $promotion = $this->promotionService->get($id);

        if (null === $promotion) {
            return $this->promotionNotFound();
        }

        $this->promotionService->delete($promotion);

        return $this->json(null, Response::HTTP_NO_CONTENT);
    }

    #[Route('/{id}/active', name: 'api_admin_promotion_active', methods: ['PATCH'])]
    public function active(int $id, Request $request): JsonResponse
    {
        $promotion = $this->promotionService->get($id);

        if (null === $promotion) {
            return $this->promotionNotFound();
        }

        /** @var UpdatePromotionActiveRequest $dto */
        $dto = $this->deserializeAndValidate($request, UpdatePromotionActiveRequest::class);

        $promotion = $this->promotionService->setActive($promotion, $dto->isActive);

        return $this->json(PromotionResponse::fromEntity($promotion));
    }

    #[Route('/{id}/photo', name: 'api_admin_promotion_photo_upload', methods: ['POST'])]
    public function uploadPhoto(int $id, Request $request): JsonResponse
    {
        $promotion = $this->promotionService->get($id);

        if (null === $promotion) {
            return $this->promotionNotFound();
        }

        $file = $request->files->get('photo');

        if (null === $file) {
            throw new InvalidOperationException('No photo was uploaded.');
        }

        $promotion = $this->promotionService->setPhoto($promotion, $file);

        return $this->json(PromotionResponse::fromEntity($promotion));
    }

    #[Route('/{id}/photo', name: 'api_admin_promotion_photo_remove', methods: ['DELETE'])]
    public function removePhoto(int $id): JsonResponse
    {
        $promotion = $this->promotionService->get($id);

        if (null === $promotion) {
            return $this->promotionNotFound();
        }

        $promotion = $this->promotionService->removePhoto($promotion);

        return $this->json(PromotionResponse::fromEntity($promotion));
    }

    private function promotionNotFound(): JsonResponse
    {
        return $this->json(
            ['message' => 'Promotion not found.'],
            Response::HTTP_NOT_FOUND
        );
    }
}
