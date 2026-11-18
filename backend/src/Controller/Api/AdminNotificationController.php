<?php

namespace App\Controller\Api;

use App\Dto\Admin\SendPushCampaignRequest;
use App\Entity\Promotion;
use App\Entity\PushCampaign;
use App\Entity\User;
use App\Repository\DeviceTokenRepository;
use App\Repository\PushCampaignRepository;
use App\Service\PushNotificationService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

/**
 * The admin's "Notifications" page: a notification to every customer's
 * phone ("⚡ FLASH HOUR : -35% ! Code promo : RB35"), and the ones sent
 * before. A tap opens the app, on the linked promotion if there's one.
 */
#[Route('/api/admin/notifications')]
#[IsGranted('ROLE_ADMIN')]
final class AdminNotificationController extends AbstractApiController
{
    /** A second send this soon is a double click, not a new campaign. */
    private const MIN_SECONDS_BETWEEN_SENDS = 60;

    public function __construct(
        SerializerInterface $serializer,
        ValidatorInterface $validator,
        private readonly DeviceTokenRepository $deviceTokens,
        private readonly PushCampaignRepository $campaigns,
        private readonly PushNotificationService $push,
        private readonly EntityManagerInterface $entityManager,
    ) {
        parent::__construct($serializer, $validator);
    }

    #[Route('', name: 'api_admin_notification_list', methods: ['GET'])]
    public function list(): JsonResponse
    {
        return $this->json([
            'reachableDevices' => count($this->deviceTokens->findClientTokenStrings()),
            'campaigns' => array_map($this->toArray(...), $this->campaigns->latest(30)),
        ]);
    }

    #[Route('', name: 'api_admin_notification_send', methods: ['POST'])]
    public function send(Request $request): JsonResponse
    {
        /** @var SendPushCampaignRequest $dto */
        $dto = $this->deserializeAndValidate($request, SendPushCampaignRequest::class);

        $promotion = null;
        if (null !== $dto->promotionId) {
            $promotion = $this->entityManager->find(Promotion::class, $dto->promotionId);
            if (null === $promotion) {
                return $this->json(['message' => 'Promotion not found.'], Response::HTTP_UNPROCESSABLE_ENTITY);
            }
        }

        $since = new \DateTimeImmutable(sprintf('-%d seconds', self::MIN_SECONDS_BETWEEN_SENDS));
        if ($this->campaigns->countSince($since) > 0) {
            return $this->json(
                ['message' => 'A notification was just sent. Wait a minute before sending another.'],
                Response::HTTP_TOO_MANY_REQUESTS
            );
        }

        $tokens = $this->deviceTokens->findClientTokenStrings();
        if ([] === $tokens) {
            return $this->json(
                ['message' => 'No customer has turned notifications on yet.'],
                Response::HTTP_UNPROCESSABLE_ENTITY
            );
        }

        $title = trim((string) $dto->title);
        $body = trim((string) $dto->body);
        $data = ['type' => 'promotion'];
        if (null !== $promotion) {
            $data['promotionId'] = (string) $promotion->getId();
        }

        $delivered = $this->push->broadcast($tokens, $title, $body, $data);

        $admin = $this->getUser();
        $campaign = (new PushCampaign())
            ->setTitle($title)
            ->setBody($body)
            ->setPromotion($promotion)
            ->setSentBy($admin instanceof User ? $admin : null)
            ->setRecipients(count($tokens))
            ->setDelivered($delivered);
        $this->entityManager->persist($campaign);
        $this->entityManager->flush();

        return $this->json($this->toArray($campaign), Response::HTTP_CREATED);
    }

    /**
     * @return array<string, mixed>
     */
    private function toArray(PushCampaign $campaign): array
    {
        return [
            'id' => $campaign->getId(),
            'title' => $campaign->getTitle(),
            'body' => $campaign->getBody(),
            'promotionId' => $campaign->getPromotion()?->getId(),
            'promotionTitle' => $campaign->getPromotion()?->getTitle(),
            'recipients' => $campaign->getRecipients(),
            // null: push is off on this server (no Firebase key): nothing left.
            'delivered' => $campaign->getDelivered(),
            'sentBy' => $campaign->getSentBy()?->getName(),
            'sentAt' => $campaign->getSentAt()?->format(\DateTimeInterface::ATOM),
        ];
    }
}
