# andrewzick.com

This is my personal website :tada:

## Installation

A mess tbh. Currently runs on [Caddy](https://github.com/caddyserver/caddy/). Working on cleaning this up and possibly containerizing it.

## Todo
- Rework the whole website to run as a container
  - ~~Run Caddy locally in a container~~
  - ~~Setup my website inside this local container~~
  - Try running the website in ECS or something?
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
- Get ECR credentials with `aws ecr get-login-password | docker login --username AWS --password-stdin 153765495495.dkr.ecr.us-east-1.amazonaws.com`
- Tag the new image wth `docker tag IMAGE_ID 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:my-image-tag`. The ECR repository is call `personal-website` and the tag for the website would be a number like `1`.
- Push the image to ECR with `docker push 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:my-image-tag`