# andrewzick.com

This is my personal website :tada:

## Installation

A mess tbh. Currently runs on [Caddy](https://github.com/caddyserver/caddy/). Working on cleaning this up and possibly containerizing it.

## Todo
- Rework the whole website to run as a container
  - ~~Run Caddy locally in a container~~
  - ~~Setup my website inside this local container~~
  - Try running the website in ECS or something?
  	- Start up an EC2 that gets traffic via an NLB
  		- ~~Try running the website from a directory on the EC2~~
  		- ~~Needed to (bad security) copy creds onto the EC2 to pull the website docker image~~
  		- ~~Try running Docker on an EC2 and then running the website container on that~~
  		- ~~Needed to `docker run` with ports 80 and 443 explicitly in the CLI call~~
  		- ~~Needed to add `dev.andrewzick.com` to the Caddyfile and a CNAME DNS record to the NLB~~
  - Evaluate if a container is a better way to run my website (cost, ease of deployment, etc.)


## Future
- Add pre-commit to this repo
- Run my website off IPv6
- Fix the top-level folder organization to have the html pages in a folder, but still work with templating
- Integrate my CBB bracket and SLP ideas into the website, possible as subdomains


## Done
- Added a bunch of kooky joke pages
- Edited my main page summary a billion times
- Constantly flip flopped on whether or not to have my face on the site

###

## Pushing a Docker image to ECR
- Build a new image with `docker build -f Dockerfile --target DEV -t 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:$IMAGE_TAG_NUMBER .` The ECR repository is called `personal-website` and the tag for the website would be a number like `4`. Specify the target as `DEV` or `PROD` to build with the corresponding Caddyfiles.
- Get ECR credentials with `aws ecr get-login-password | docker login --username AWS --password-stdin 153765495495.dkr.ecr.us-east-1.amazonaws.com`
- Push the image to ECR with `docker push 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:$IMAGE_TAG_NUMBER`

## Running the Docker image on an EC2
- Install Docker and start the daemon
- Pull the website image with `docker pull 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:my-image-tag`
- Run the image with `docker run -dt -p 80:80 -p 443:443 -p 2019:2019 -p 8000:8000 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:my-image-tag`