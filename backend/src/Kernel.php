<?php

namespace App;

use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;

class Kernel extends BaseKernel
{
    use MicroKernelTrait;

    /**
     * Secrets shipped with placeholder values in .env / .env.example. Booting
     * prod with any of these still in place means the app is running with a
     * publicly known APP_SECRET or JWT passphrase, so fail loudly instead.
     *
     * @var array<string, list<string>>
     */
    private const INSECURE_SECRET_DEFAULTS = [
        'APP_SECRET' => ['change-me', ''],
        'JWT_PASSPHRASE' => ['change-me'],
    ];

    public function boot(): void
    {
        parent::boot();

        if ('prod' !== $this->environment) {
            return;
        }

        foreach (self::INSECURE_SECRET_DEFAULTS as $var => $placeholders) {
            $value = $_SERVER[$var] ?? $_ENV[$var] ?? '';

            if (in_array($value, $placeholders, true)) {
                throw new \RuntimeException(sprintf(
                    '%s is still set to a placeholder value. Set a real secret in .env.local (or a real environment variable) before running in prod.',
                    $var
                ));
            }
        }
    }
}
