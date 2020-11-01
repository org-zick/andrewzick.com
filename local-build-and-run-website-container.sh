# Build the container with the local Caddyfile
docker build -f Dockerfile --target LOCAL -t local-website .

# Run the local container
docker run -p 80:80 -p 443:443 -p 2019:2019 local-website
