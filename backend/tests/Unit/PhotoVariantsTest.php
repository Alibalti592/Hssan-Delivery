<?php

namespace App\Tests\Unit;

use App\Service\PhotoVariants;
use PHPUnit\Framework\TestCase;
use Psr\Log\NullLogger;

final class PhotoVariantsTest extends TestCase
{
    private string $dir;

    protected function setUp(): void
    {
        if (!function_exists('imagewebp')) {
            self::markTestSkipped('GD without WebP.');
        }
        $this->dir = sys_get_temp_dir().'/photo-variants-'.bin2hex(random_bytes(4)).'/products';
        mkdir($this->dir, 0775, true);
    }

    protected function tearDown(): void
    {
        exec('rm -rf '.escapeshellarg(dirname($this->dir)));
    }

    public function testMakesSmallerCopiesAndLeavesTheOriginal(): void
    {
        $original = $this->photo('dish.jpg', 1400, 1000);
        $before = md5_file($original);
        $variants = new PhotoVariants(new NullLogger());

        self::assertSame(2, $variants->generate($original));

        $small = $this->dir.'/w480/dish.webp';
        $medium = $this->dir.'/w960/dish.webp';
        self::assertSame(480, (getimagesize($small) ?: [0])[0]);
        self::assertSame(960, (getimagesize($medium) ?: [0])[0]);
        self::assertSame('image/webp', (getimagesize($small) ?: [])['mime'] ?? null);
        self::assertLessThan(filesize($original), filesize($small));
        self::assertSame($before, md5_file($original), 'the original is never changed');

        // Run again: nothing left to make.
        self::assertSame(0, $variants->generate($original));

        $variants->remove($original);
        self::assertFileDoesNotExist($small);
        self::assertFileDoesNotExist($medium);
    }

    public function testASmallPhotoStillGetsItsCopiesAtItsOwnSize(): void
    {
        $logo = $this->photo('logo.png', 300, 300);

        self::assertSame(2, (new PhotoVariants(new NullLogger()))->generate($logo));
        self::assertSame(300, (getimagesize($this->dir.'/w960/logo.webp') ?: [0])[0]);
    }

    public function testAPhonePhotoStoredSidewaysIsTurnedUpright(): void
    {
        if (!function_exists('exif_read_data')) {
            self::markTestSkipped('No exif extension.');
        }
        // 60 by 30 as stored, with a note to turn it a quarter clockwise.
        copy(__DIR__.'/../Fixtures/sideways-phone-photo.jpg', $this->dir.'/phone.jpg');

        (new PhotoVariants(new NullLogger()))->generate($this->dir.'/phone.jpg');

        self::assertSame([30, 60], array_slice(getimagesize($this->dir.'/w480/phone.webp') ?: [], 0, 2));
    }

    public function testAFileThatIsNotAnImageIsSkipped(): void
    {
        file_put_contents($this->dir.'/broken.jpg', 'not an image');

        self::assertSame(0, (new PhotoVariants(new NullLogger()))->generate($this->dir.'/broken.jpg'));
        self::assertFileDoesNotExist($this->dir.'/w480/broken.webp');
    }

    private function photo(string $name, int $width, int $height): string
    {
        $image = imagecreatetruecolor($width, $height);
        for ($x = 0; $x < $width; $x += 20) {
            imagefilledrectangle($image, $x, 0, $x + 10, $height, (int) imagecolorallocate($image, $x % 255, 120, 200));
        }
        $path = $this->dir.'/'.$name;
        str_ends_with($name, '.png') ? imagepng($image, $path) : imagejpeg($image, $path, 90);

        return $path;
    }
}
