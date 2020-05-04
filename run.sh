# RUN ONCE:
# docker volume create personal-website-data

docker kill personal-website
docker build -f Dockerfile -t personal-website .
docker run --rm --name personal-website -d -p 80:80 -p 443:443 -p 2019:2019 -v personal-website-data:/data personal-website
docker logs -f personal-website
