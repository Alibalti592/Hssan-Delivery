# Production image for the React admin dashboard: a Vite build served as
# static files by nginx, with client-side routing support.
#
# Build (from the admin/ directory):
#   docker build --build-arg VITE_API_URL=https://api.hssan.example \
#     -t hssan-delivery-admin .
#
# VITE_API_URL is a build-time value — Vite bakes it into the built JS, so
# it must be supplied at `docker build` time, not `docker run` time.

FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG VITE_API_URL=http://127.0.0.1:8000
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

FROM nginx:alpine AS app
COPY --from=build /app/dist /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
