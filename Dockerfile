# note: never use the :latest tag in a production site
FROM caddy:2.0.0-rc.3

COPY Caddyfile /etc/caddy/Caddyfile
COPY . /personal-website