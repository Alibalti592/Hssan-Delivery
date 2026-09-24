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

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev \
        libicu-dev \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j"$(nproc)" pdo pdo_pgsql intl opcache \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# Symfony serves from public/, not the vhost's default docroot.
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

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

ENV APP_ENV=prod
EXPOSE 80

ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2-foreground"]
