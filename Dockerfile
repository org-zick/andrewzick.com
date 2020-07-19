# note: never use the :latest tag in a production site
FROM caddy:2.0.0 AS base

FROM base AS dev
COPY Caddyfile-dev /etc/caddy/Caddyfile
COPY . /personal-website

FROM base AS prod
COPY Caddyfile-prod /etc/caddy/Caddyfile
COPY . /personal-website