<?php

namespace App\Controller\Api;

use App\Exception\ValidationFailedException;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Serializer\Exception\NotEncodableValueException;
use Symfony\Component\Serializer\Exception\NotNormalizableValueException;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

abstract class AbstractApiController extends AbstractController
{
    public function __construct(
        protected readonly SerializerInterface $serializer,
        protected readonly ValidatorInterface $validator,
    ) {
    }

    /**
     * Deserializes the request body into $dtoClass and validates it.
     *
     * @template T of object
     *
     * @param class-string<T> $dtoClass
     *
     * @return T
     *
     * @throws ValidationFailedException when the body is malformed or fails validation
     */
    protected function deserializeAndValidate(Request $request, string $dtoClass): object
    {
        try {
            $dto = $this->serializer->deserialize(
                $request->getContent(),
                $dtoClass,
                'json'
            );
        } catch (NotNormalizableValueException|NotEncodableValueException) {
            throw new ValidationFailedException([['field' => 'request', 'message' => 'Invalid request data.']]);
        }

        $violations = $this->validator->validate($dto);

        if (count($violations) > 0) {
            $errors = [];

            foreach ($violations as $violation) {
                $errors[] = [
                    'field' => $violation->getPropertyPath(),
                    'message' => $violation->getMessage(),
                ];
            }

            throw new ValidationFailedException($errors);
        }

        return $dto;
    }
}
