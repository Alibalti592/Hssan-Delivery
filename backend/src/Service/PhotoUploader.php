<?php

namespace App\Service;

use App\Exception\InvalidOperationException;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpFoundation\File\UploadedFile;

/**
 * Stores restaurant/product photos on the local filesystem, under
 * public/uploads/{subdirectory}/, so they're served directly by the web
 * server. Entities keep only the stored filename; callers build the public
 * URL with self::url().
 */
final class PhotoUploader
{
    private const ALLOWED_MIME_TYPES = [
        'image/jpeg',
        'image/png',
        'image/webp',
    ];

    private const MAX_SIZE_BYTES = 5 * 1024 * 1024;

    public function __construct(
        #[Autowire('%kernel.project_dir%/public/uploads')]
        private readonly string $uploadsDir,
    ) {
    }

    /**
     * @throws InvalidOperationException if the file is missing, too large, or not an accepted image type
     */
    public function store(UploadedFile $file, string $subdirectory): string
    {
        if (!$file->isValid()) {
            throw new InvalidOperationException('The uploaded file could not be read.');
        }

        if ($file->getSize() > self::MAX_SIZE_BYTES) {
            throw new InvalidOperationException('Image must be smaller than 5 MB.');
        }

        if (!in_array($file->getMimeType(), self::ALLOWED_MIME_TYPES, true)) {
            throw new InvalidOperationException('Only JPEG, PNG or WebP images are allowed.');
        }

        $filename = bin2hex(random_bytes(16)).'.'.($file->guessExtension() ?? 'bin');

        $file->move($this->uploadsDir.'/'.$subdirectory, $filename);

        return $filename;
    }

    /**
     * Copies a stored photo into another subdirectory under a fresh name,
     * so the two owners can later replace or delete theirs independently.
     *
     * @return string|null the copy's filename; null when there is nothing
     *                     to copy (no photo, or its file is missing)
     */
    public function copy(?string $filename, string $fromSubdirectory, string $toSubdirectory): ?string
    {
        if (null === $filename) {
            return null;
        }

        $source = $this->uploadsDir.'/'.$fromSubdirectory.'/'.$filename;

        if (!is_file($source)) {
            return null;
        }

        $extension = pathinfo($filename, PATHINFO_EXTENSION);
        $copy = bin2hex(random_bytes(16)).('' !== $extension ? '.'.$extension : '');
        $directory = $this->uploadsDir.'/'.$toSubdirectory;

        if (!is_dir($directory)) {
            mkdir($directory, 0775, true);
        }

        if (!copy($source, $directory.'/'.$copy)) {
            return null;
        }

        return $copy;
    }

    public function delete(?string $filename, string $subdirectory): void
    {
        if (null === $filename) {
            return;
        }

        $path = $this->uploadsDir.'/'.$subdirectory.'/'.$filename;

        if (is_file($path)) {
            @unlink($path);
        }
    }

    public static function url(?string $filename, string $subdirectory): ?string
    {
        return null === $filename
            ? null
            : '/uploads/'.$subdirectory.'/'.$filename;
    }
}
