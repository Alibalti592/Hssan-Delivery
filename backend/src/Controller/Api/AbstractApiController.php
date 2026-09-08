<?php

namespace App\Controller\Api;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Validator\ConstraintViolationListInterface;

abstract class AbstractApiController extends AbstractController
{
    protected function validationErrorResponse(
        ConstraintViolationListInterface $violations
    ): JsonResponse {
        $errors = [];

        foreach ($violations as $violation) {
            $errors[$violation->getPropertyPath()] = $violation->getMessage();
        }

        return $this->json(
            [
                'error' => 'Validation failed',
                'fields' => $errors,
            ],
            Response::HTTP_UNPROCESSABLE_ENTITY
        );
    }
}