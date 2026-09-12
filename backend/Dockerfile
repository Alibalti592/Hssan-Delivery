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
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p var/cache var/log public/uploads config/jwt \
    && chown -R www-data:www-data var public/uploads config/jwt

ENV APP_ENV=prod
EXPOSE 80

ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2-foreground"]
