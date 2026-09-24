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
# whatever existed then.
chown -R www-data:www-data var config/jwt

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

# TEMPORARY DIAGNOSTIC: the app-level CORS logic was verified correct by
# booting the kernel directly (a simulated OPTIONS request produced the
# exact expected Access-Control-Allow-* headers) and CORS_ALLOW_ORIGIN was
# confirmed to reach the container byte-for-byte correct — yet the browser
# still reports a CORS error, with no actual POST ever recorded in Railway's
# traffic logs, only OPTIONS. That means whatever is wrong sits between
# Apache and PHP, or in how Railway's edge forwards the request — neither of
# which the kernel simulation exercises. This starts Apache, fires the exact
# same preflight over a raw socket to Apache on its own container (bypassing
# Railway's edge and any external network entirely), and dumps the full raw
# HTTP response Apache/PHP actually produces, before handing off to the real
# foreground process. Remove once the mismatch is root-caused.
apache2ctl start
sleep 2
php -r '
$fp = @fsockopen("127.0.0.1", 80, $errno, $errstr, 5);
if (!$fp) {
    echo "DIAG: connect failed: $errstr ($errno)\n";
} else {
    $req = "OPTIONS /api/auth/login HTTP/1.1\r\n"
         . "Host: hssan-delivery-production.up.railway.app\r\n"
         . "Origin: https://admin-puce-xi-35.vercel.app\r\n"
         . "Access-Control-Request-Method: POST\r\n"
         . "Access-Control-Request-Headers: content-type,x-client-platform\r\n"
         . "Connection: close\r\n\r\n";
    fwrite($fp, $req);
    $resp = "";
    while (!feof($fp)) { $resp .= fread($fp, 8192); }
    fclose($fp);
    echo "DIAG RAW RESPONSE START\n" . $resp . "DIAG RAW RESPONSE END\n";
}
'
apache2ctl stop
sleep 1

exec "$@"
