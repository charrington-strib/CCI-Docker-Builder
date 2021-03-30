#!/bin/bash -euf -o pipefail

# This script builds a CircleCI build/test/deploy docker image.
# Change VER_* to publicly available versions of PHP and Node. This script will then generate tagged
# docker images corresponding to those versions.

VER_PHP=7.4.16
VER_NODE=12.18.3

# Adjust these if needed.
AWS_ACCT=903601045739
AWS_REGION=us-west-1
REPO=cci

T=$AWS_ACCT.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO
CCI_GITHUB_ROOT="https://raw.githubusercontent.com/CircleCI-Public/circleci-dockerfiles/master"

aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCT.dkr.ecr.$AWS_REGION.amazonaws.com

# Get the CircleCI PHP recipe for the specific PHP version and build it locally, and also inject a
# sockets extension install command while we're here (needed by datadog)
( curl "$CCI_GITHUB_ROOT/php/images/$VER_PHP-fpm-buster/Dockerfile" ; echo RUN sudo docker-php-ext-install sockets ) | \
    docker build -t $REPO:php$VER_PHP -

# Get the Node recipe and inject our specific required Node version
curl "$CCI_GITHUB_ROOT/php/images/$VER_PHP-fpm-buster/node/Dockerfile" | \
    sed -e "s/^FROM .*$/FROM $REPO:php$VER_PHP/" -e "s/^ENV NODE_VERSION.*/ENV NODE_VERSION $VER_NODE/" |\
    docker build -t $REPO:php$VER_PHP-node$VER_NODE -

# Get the browsers layer and put that on too
curl "$CCI_GITHUB_ROOT/php/images/$VER_PHP-fpm-buster/node-browsers-legacy/Dockerfile" | \
    sed -e "s/^FROM .*$/FROM $REPO:php$VER_PHP-node$VER_NODE/" |\
    docker build -t $REPO:php$VER_PHP-node$VER_NODE-browsers -

# Tag with our private registry and push
docker tag $REPO:php$VER_PHP-node$VER_NODE-browsers $T:php$VER_PHP-node$VER_NODE-browsers
docker push $T:php$VER_PHP-node$VER_NODE-browsers


