# Production image for the Symfony API. Two stages: install PHP
# dependencies with Composer, then copy the app into a slim php-apache
# runtime — the Composer binary and its cache never end up in the final
# image.
#
# Build (from the backend/ directory):
#   docker build -t hssan-delivery-backend .
#
# Run:
#   docker run -p 8000:80 \
#     -e APP_SECRET=... -e JWT_PASSPHRASE=... -e DATABASE_URL=... \
#     -e LOCK_DSN=... \
#     hssan-delivery-backend
#
# JWT keypair and pending migrations are handled at container start by
# docker/entrypoint.sh — see that file for details.

FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction
COPY . .
RUN composer dump-autoload --optimize --no-dev --classmap-authoritative

FROM php:8.2-apache AS app

# The apt-get install below can trigger apache2's own postinst script,
# which re-enables Debian's default MPM (mpm_event) alongside the
# mpm_prefork this base image already has enabled for mod_php (prefork is
# required — mod_php isn't thread-safe, so it's incompatible with the
# threaded event/worker MPMs). Apache refuses to start with both loaded
# ("AH00534: More than one MPM loaded"), so force prefork back on
# explicitly; a2dismod on an already-disabled module is a harmless no-op.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev \
        libicu-dev \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j"$(nproc)" pdo pdo_pgsql intl opcache \
    && a2enmod rewrite \
    && (a2dismod mpm_event mpm_worker 2>/dev/null || true) \
    && a2enmod mpm_prefork \
    && rm -rf /var/lib/apt/lists/*

# Symfony serves from public/, not the vhost's default docroot.
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# This image ships no public/.htaccess (not installed via symfony/apache-pack)
# and the base vhost has no rewrite/fallback rule of its own, so nothing
# routes a "pretty" URL like /api/auth/login to index.php -- only requests
# that map to a real file (e.g. "/" via DirectoryIndex, which resolves
# straight to the real public/index.php) ever reach PHP. Every other path,
# OPTIONS preflights included, was being answered directly by Apache's own
# bare default handler (a 404 for GET/POST, or for OPTIONS specifically a
# contentless 200 just listing "Allow: HEAD,GET,POST,OPTIONS") -- Symfony,
# and therefore Nelmio's CORS listener, never even saw the request. This is
# the modern (no .htaccess needed) equivalent of Symfony's recommended
# front-controller rewrite: send anything that isn't a real file to
# index.php, for every HTTP method.
RUN sed -ri -e '/DocumentRoot/a\    FallbackResource /index.php' /etc/apache2/sites-available/*.conf

# Same missing-.htaccess gap as above: Apache strips any Authorization header
# that isn't HTTP Basic before handing the request to PHP, so the mobile
# app's "Authorization: Bearer <jwt>" never reached Symfony -- login
# succeeded, then every authenticated request 401'd. (The admin dashboard
# was unaffected only because it authenticates via the BEARER cookie.)
# LexikJWTAuthenticationBundle's docs prescribe exactly this rule for Apache.
RUN echo 'SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1' > /etc/apache2/conf-available/pass-authorization.conf \
    && a2enconf pass-authorization

# Uploaded photos are static files Apache serves directly, so Nelmio's CORS
# listener (PHP, /api only) never touches them. The admin dashboard renders
# them with plain <img> tags, which don't need CORS -- but the Flutter web
# client's Image.network fetches the bytes and decodes them itself, which is
# a cross-origin fetch the browser blocks without this header, leaving every
# photo blank. They're public, non-credentialed images, so a wildcard is fine.
#
# Matched by URL rather than directory: public/uploads is a symlink into
# var/storage (the persistent volume -- see docker/entrypoint.sh), so the
# filesystem path Apache ends up at isn't under public/. The explicit
# Require grant covers that symlink target.
RUN a2enmod headers \
    && printf '%s\n' \
        '<LocationMatch "^/uploads/">' \
        '    Header set Access-Control-Allow-Origin "*"' \
        '</LocationMatch>' \
        '<Directory /var/www/html/var/storage/uploads>' \
        '    Options FollowSymLinks' \
        '    Require all granted' \
        '</Directory>' > /etc/apache2/conf-available/uploads-cors.conf \
    && a2enconf uploads-cors

WORKDIR /var/www/html
COPY --from=vendor /app ./
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
# Symfony's Dotenv::bootEnv() requires a ".env" file to exist on disk, even
# when every var it'd load (APP_SECRET, DATABASE_URL, etc.) is already set
# as a real environment variable by the host (Railway, Render, docker run
# -e, ...). ".env" itself is gitignored — it never reaches a clean
# checkout — so a fresh image build has nothing at this path unless we put
# something there. ".env.example"'s placeholder values are harmless:
# Dotenv only fills in vars that aren't already set, so real host-provided
# vars always win over whatever's in this file (the same reasoning the
# backend CI workflow already documents for its own "cp .env.example .env"
# step).
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p var/cache var/log public/uploads config/jwt \
    && chown -R www-data:www-data var public/uploads config/jwt \
    && cp .env.example .env

# Belt-and-suspenders on top of the a2dismod/a2enmod calls above: makes
# sure only mpm_prefork's symlinks exist, as its own distinct build layer.
# On most hosts this alone would be redundant with the earlier a2dismod
# call — but a deployed instance of this image on Railway was observed
# booting with mpm_event.load's original base-image timestamp completely
# unchanged, as if this exact rm -f (in this exact layer) never took
# effect there, while everything else in the same layer (the prefork
# symlinks below) got a fresh build-time timestamp as expected. Whatever
# that platform's build pipeline is doing to materialize the final
# container filesystem, it isn't reliably preserving this deletion. The
# fix that actually holds regardless is in docker/entrypoint.sh, which
# repeats this same rm -f + relink at container *runtime* instead —
# there's no build/export/snapshot step for that to get lost in. Kept
# here too since it's correct and harmless on every other host.
RUN rm -f /etc/apache2/mods-enabled/mpm_event.load /etc/apache2/mods-enabled/mpm_event.conf \
        /etc/apache2/mods-enabled/mpm_worker.load /etc/apache2/mods-enabled/mpm_worker.conf \
    && ln -sf ../mods-available/mpm_prefork.load /etc/apache2/mods-enabled/mpm_prefork.load \
    && ln -sf ../mods-available/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf

ENV APP_ENV=prod
EXPOSE 80

ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2-foreground"]
