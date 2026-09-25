#!/bin/sh
set -e

# Railway allows one volume per service, mounted at var/storage (outside the
# webroot). Both things that must survive a redeploy live there: uploaded
# photos, and the JWT keypair -- regenerating the keypair on every boot
# silently invalidated every admin and client session after each deploy.
# (docker-compose.staging.yml mounts public/uploads and config/jwt as their
# own volumes instead; the guards below leave those alone.)
mkdir -p var/storage/uploads var/storage/jwt

# One-time migration: the volume used to be mounted directly at
# public/uploads, so photos uploaded back then sit at its root.
for d in restaurants products promotions; do
    if [ -d "var/storage/$d" ] && [ ! -e "var/storage/uploads/$d" ]; then
        mv "var/storage/$d" "var/storage/uploads/$d"
    fi
done

# Point public/uploads and config/jwt at storage -- but only when each is
# still the image's own empty directory. Never touch a mount point (a bind
# mount can sit on the same device, hence mountpoint as well as the device
# check) or a directory that already holds files.
link_to_storage() {
    path=$1
    target=$2
    if [ ! -L "$path" ] \
        && ! mountpoint -q "$path" 2>/dev/null \
        && [ -z "$(ls -A "$path" 2>/dev/null)" ] \
        && [ "$(stat -c %d "$path")" = "$(stat -c %d "$(dirname "$path")")" ]; then
        rmdir "$path"
        ln -s "$target" "$path"
    fi
}
link_to_storage public/uploads ../var/storage/uploads
link_to_storage config/jwt ../var/storage/jwt

if ! mountpoint -q var/storage 2>/dev/null && ! mountpoint -q public/uploads 2>/dev/null; then
    echo "WARNING: no volume mounted at var/storage -- uploaded photos and the JWT keypair will be lost on the next deploy." >&2
fi

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

# Opt-in, off by default: some hosts (Railway) give no shell/exec access
# into a running container, so there's otherwise no way to run a one-off
# console command to bootstrap the first admin account. AppFixtures itself
# is idempotent (it checks for the admin phone before creating anything),
# so this is safe to leave set across multiple boots — but the intent is
# to set SEED_FIXTURES=true once, confirm it worked, then unset it.
if [ "${SEED_FIXTURES:-}" = "true" ]; then
    php bin/console doctrine:fixtures:load --append --no-interaction
fi

# This script (and the two commands above) run as root — Apache's master
# process needs root to bind port 80 — but the workers that actually serve
# requests drop to www-data. Booting the Symfony kernel for those commands
# warms var/cache/prod/ as a side effect, as root, creating directories
# Apache's www-data workers can't write into afterwards (root-owned dirs
# from mkdir default to 755, not group/other-writable) — the first real
# request then fails with a 500 trying to rewrite the routes cache.
# Re-chown before handing off to Apache so www-data owns whatever root
# just created, same as the Dockerfile already does at build time for
# whatever existed then. This also covers var/storage, which a host mounts
# fresh on every boot, typically owned by root -- without it PhotoUploader's
# next write fails. Only entries not already owned by www-data are touched,
# so boot time doesn't grow with the number of stored photos. -H follows
# public/uploads and config/jwt when they're symlinks into var/storage, or
# separate volumes (docker-compose.staging.yml).
find -H var config/jwt public/uploads \( ! -user www-data -o ! -group www-data \) \
    -exec chown -h www-data:www-data {} +

# The exact same rm -f done at build time (Dockerfile) doesn't stick on
# Railway: diagnostic logging confirmed mpm_prefork.load gets a fresh
# build-time timestamp there, but mpm_event.load — deleted in that same
# build layer — still shows the *original base-image* timestamp at
# runtime, unchanged, as if the deletion never happened. Something about
# how that platform materializes the final container filesystem from the
# built image isn't preserving this specific deletion. Doing it here
# instead sidesteps that entirely: this runs on the container's own live
# writable filesystem at the moment it's actually booting, not through
# any build/export/snapshot pipeline, so there's no layer to lose it.
rm -f /etc/apache2/mods-enabled/mpm_event.load /etc/apache2/mods-enabled/mpm_event.conf \
      /etc/apache2/mods-enabled/mpm_worker.load /etc/apache2/mods-enabled/mpm_worker.conf
ln -sf ../mods-available/mpm_prefork.load /etc/apache2/mods-enabled/mpm_prefork.load
ln -sf ../mods-available/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf

exec "$@"
