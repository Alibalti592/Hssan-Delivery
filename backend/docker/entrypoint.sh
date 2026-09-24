#!/bin/sh
set -e

# JWT keys are gitignored (see .gitignore) and never baked into the image —
# generate them on first boot from JWT_PASSPHRASE so a deploy only needs to
# supply that one secret, not a key file. Skipped if a keypair was already
# mounted in (e.g. from a persistent volume across deploys).
if [ ! -f config/jwt/private.pem ]; then
    php bin/console lexik:jwt:generate-keypair --no-interaction
fi

# Applies any migrations not yet run. Safe to run on every boot: a no-op
# when the schema is already current, and --allow-no-migration avoids
# failing the very first deploy before any migration exists.
php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration

# This script (and the two commands above) run as root — Apache's master
# process needs root to bind port 80 — but the workers that actually serve
# requests drop to www-data. Booting the Symfony kernel for those commands
# warms var/cache/prod/ as a side effect, as root, creating directories
# Apache's www-data workers can't write into afterwards (root-owned dirs
# from mkdir default to 755, not group/other-writable) — the first real
# request then fails with a 500 trying to rewrite the routes cache.
# Re-chown before handing off to Apache so www-data owns whatever root
# just created, same as the Dockerfile already does at build time for
# whatever existed then.
chown -R www-data:www-data var config/jwt

exec "$@"
