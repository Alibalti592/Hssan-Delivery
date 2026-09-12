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

exec "$@"
