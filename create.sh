#!/bin/bash
set -e


#Important prompts
echo "***Welcome! Let's build this stack."
echo " "
echo "***Docker Desktop must be installed locally to run this script. https://www.docker.com/products/docker-desktop"
echo "***The script requires an AWS Access Key ID, Secret Access Key, Session Token"
echo " "
read -srp "**Enter your AWS Access Key ID: " AWS_ACCESS_KEY_ID
echo
read -srp "**Enter your AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo
read -srp "**Enter your AWS Session Token: " AWS_SESSION_TOKEN
echo
read -p "**Enter a Cluster name (must be 3-30 alphanumeric characters & can include underscores/hyphens): " CLUSTER_NAME
read -p "**Enter an AWS Region (us-east-1, us-east-2, us-west-1, us-west-2) for Infrastructure Cluster location: " AWS_REGION

#Write user entries to app.env for install
echo "export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"" > ./scripts/user.env
echo "export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"" >> ./scripts/user.env
echo "export AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}"" >> ./scripts/user.env
LEN=$(echo ${#CLUSTER_NAME})
if [ $LEN -lt 3 ]; then
    # Set a default name with today's date
    env_name=$(date +'a%m-%d-%Y-%H-%M-%S')
fi
# Name must be less than 32 characters per AWS
echo "export CLUSTER_NAME="${CLUSTER_NAME}"" | cut -c1-30 >> ./scripts/user.env
echo "export AWS_REGION="${AWS_REGION}"" >> ./scripts/user.env


# Build common docker builder image
docker build -t effectual-devsecops . -f ci/docker/Dockerfile

# Install infrastructure using common docker builder image
docker-compose -f ci/docker/install.yaml up