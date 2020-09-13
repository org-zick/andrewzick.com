# note: never use the :latest tag in a production site
FROM caddy:2.0.0 AS base
COPY . /personal-website

FROM base AS local
COPY Caddyfile-local /etc/caddy/Caddyfile

FROM base AS dev
COPY Caddyfile-dev /etc/caddy/Caddyfile

FROM base AS prod
COPY Caddyfile-prod /etc/caddy/Caddyfile
