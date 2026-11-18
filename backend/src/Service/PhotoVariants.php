<?php

namespace App\Service;

use Psr\Log\LoggerInterface;

/**
 * Smaller copies of each catalogue photo, so the app downloads what it
 * shows rather than the upload: a dish shown 96 pixels wide in a menu took
 * a 1400-pixel, 300 KB photo, about ten times what the screen needs.
 *
 * Next to "products/abc.jpg" sit "products/w480/abc.webp" and
 * "products/w960/abc.webp". The app picks the smallest one wide enough for
 * where the photo is shown, and falls back to the original when a copy is
 * missing; the originals are never changed.
 */
final class PhotoVariants
{
    /** Widths, in pixels, of the copies made of every photo. */
    public const WIDTHS = [480, 960];

    private const QUALITY = 78;

    public function __construct(private readonly LoggerInterface $logger)
    {
    }

    /**
     * Makes every copy of the photo at [path] that doesn't exist yet.
     *
     * @return int how many copies were made
     */
    public function generate(string $path): int
    {
        $missing = array_filter(self::WIDTHS, fn (int $width) => !is_file($this->variantPath($path, $width)));
        if ([] === $missing || !function_exists('imagewebp')) {
            return 0;
        }

        $made = 0;
        try {
            $image = @imagecreatefromstring((string) file_get_contents($path));
            if (false === $image) {
                return 0;
            }
            // Keeps PNG logos' transparency in the copies.
            imagepalettetotruecolor($image);
            imagealphablending($image, true);
            imagesavealpha($image, true);

            foreach ($missing as $width) {
                // A photo narrower than the copy is only re-encoded: the copy
                // must exist for the app to find it.
                $copy = imagesx($image) > $width ? imagescale($image, $width, -1, IMG_BICUBIC) : $image;
                if (false === $copy) {
                    continue;
                }
                imagesavealpha($copy, true);
                $target = $this->variantPath($path, $width);
                if (!is_dir(dirname($target))) {
                    mkdir(dirname($target), 0775, true);
                }
                // Written aside, then moved: the app never gets half a file.
                $partial = $target.'.part';
                if (imagewebp($copy, $partial, self::QUALITY) && rename($partial, $target)) {
                    ++$made;
                }
                @unlink($partial);
            }
        } catch (\Throwable $e) {
            // The original still works: the app falls back to it.
            $this->logger->warning('Could not make smaller copies of a photo.', ['path' => $path, 'exception' => $e]);
        }

        return $made;
    }

    public function remove(string $path): void
    {
        foreach (self::WIDTHS as $width) {
            $variant = $this->variantPath($path, $width);
            if (is_file($variant)) {
                @unlink($variant);
            }
        }
    }

    /** "…/products/abc.jpg" → "…/products/w480/abc.webp". */
    public function variantPath(string $path, int $width): string
    {
        return dirname($path).'/w'.$width.'/'.pathinfo($path, PATHINFO_FILENAME).'.webp';
    }
}
