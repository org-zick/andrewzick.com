# andrewzick.com

This is my personal website :tada:

## Installation

A mess tbh. Currently runs on [Caddy](https://github.com/caddyserver/caddy/). Working on cleaning this up and possibly containerizing it.

## Todo
- Rework the whole website to run as a container
  - ~~Run Caddy locally in a container~~
  - ~~Setup my website inside this local container~~
  - ~~Try running the website in ECS or something?~~
  	- ~~Start up an EC2 that gets traffic via an NLB~~
  		- ~~Try running the website from a directory on the EC2~~
  		- ~~Needed to (bad security) copy creds onto the EC2 to pull the website docker image~~
  			- ~~ssh in with aws.pem~~
  		- ~~Try running Docker on an EC2 and then running the website container on that~~
  		- ~~Needed to `docker run` with ports 80 and 443 explicitly in the CLI call~~
  		- ~~Needed to add `dev.andrewzick.com` to the Caddyfile and a CNAME DNS record to the NLB~~
		- ~~Try running a container website for dev.andrewzick.com~~
			- ~~Publish a dev container to ECR~~
      - ~~Spin up ASG with 1 EC2 with special ECS agent on it and then start up the task~~
			- ~~Hook up the NLB to this ECS cluster~~
  - ~~Evaluate if a container is a better way to run my website (cost, ease of deployment, etc.)~~
    - ~~Woops a little late on this one, but it's definitely more costly, roughly $25/month vs. $3/month (with RIs)~~
  - Write up a blog(?) or something other post about my experiences doing....this
    - part 1, why?
    - part 2, the old setup + background
    - part 3, what was my goal?
    - part 4, the process TM
    - part 5, success
    - part 6, cost analysis (vs. experience doing this)
    - part 7, "so you want to do the same thing?"


## Future
- Add pre-commit to this repo
- Run my website off IPv6
- Automate building the container and pushing it to ECR, possibly with...tests??
- Fix the top-level folder organization to have the html pages in a folder, but still work with templating
- Integrate my CBB bracket and SLP ideas into the website, possible as subdomains


## Done
- Added a bunch of kooky joke pages
- Edited my main page summary a billion times
- Constantly flip flopped on whether or not to have my face on the site

###

## Running the website locally:
- Try `docker ps` and if it doesn't work, then probably CMD+SPACE docker to start up the daemon.
- If any containers are running and you don't remember why, try to remember why. Then kill then.
- Run `docker build -f Dockerfile --target LOCAL .`
  - This builds the website container from the `Dockerfile` at `.` on the target `LOCAL`
  - When it's done, it will print a container ID e.g. `4f662cd7772c`. You need this.
- Run `docker run -p 80:80 -p 443:443 -p 2019:2019 $YOUR_CONTAINER_ID`.
  - The `-p` arguments are to tell docker to open those ports on the container. 2019 is the Caddy admin port.
  - Add `-d` somewhere before the ID if you want the container to run in the background.
- Hit the website via browser + `localhost`. Manually checking if changes worked is the current process.


## Pushing a Docker image to ECR
- Build a new image with `docker build -f Dockerfile --target PROD -t 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:$IMAGE_TAG_NUMBER .`
  - The ECR repository is called `personal-website` and the tag for the website would be a number like `4`.
  - You can probably look at the ECS terraform task definition to find the correct number.
  - Specify the target as `DEV` or `PROD` to build with the corresponding Caddyfiles.

- Get ECR credentials with `aws ecr get-login-password | docker login --username AWS --password-stdin 153765495495.dkr.ecr.us-east-1.amazonaws.com`. It should print "Login Succeeded".

- Push the image to ECR with `docker push 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:$IMAGE_TAG_NUMBER`. This may take a little bit.


## Spinning up a new version of the website
- This is after you have pushed the new container image to ECR.
- You need to update the ECS task in `ECS.tf` to the new image tag, whatever the number is now.

- Then it's time to go into the `terraform/` folder and run `terraform apply -var-file prod.tfvars`.
  - Refreshing state will take around 20 seconds.
  - You can add `-refresh=false` if you've _just_ run terraform to avoid waiting for state to refresh again.
  - Don't forget to review the plan before entering `yes`.
  - Destroying resources can take a few minutes, so you will have to wait and watch to ensure it succeeds.

- Once terraform succeeds, monitor the ECS console to make sure the task reaches the `RUNNING` state.
  - It may stay in the `PENDING` state for a minute or two.
  - If it fails, go investigate the Cloudwatch logs for the task.


## Running the Docker image on an EC2
- Install Docker and start the daemon
- Pull the website image with `docker pull 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:my-image-tag`
- Run the image with `docker run -dt -p 80:80 -p 443:443 -p 2019:2019 -p 8000:8000 153765495495.dkr.ecr.us-east-1.amazonaws.com/personal-website:my-image-tag`
