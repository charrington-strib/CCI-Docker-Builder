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
BUILDINFO="$USER on `scutil --get LocalHostName` at `date -u +%FT%TZ`"

aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCT.dkr.ecr.$AWS_REGION.amazonaws.com

# Get the CircleCI PHP Dockerfile for the specific PHP version, build it locally, and inject an
# install of some php extensions
( curl "$CCI_GITHUB_ROOT/php/images/$VER_PHP-fpm-buster/Dockerfile"
  echo RUN sudo docker-php-ext-install sockets pdo pdo_mysql ) | \
    docker build -t $REPO:php$VER_PHP -

# Get the Node Dockerfile and inject our specific required Node version
curl "$CCI_GITHUB_ROOT/php/images/$VER_PHP-fpm-buster/node/Dockerfile" | \
    sed -e "s/^FROM .*$/FROM $REPO:php$VER_PHP/" -e "s/^ENV NODE_VERSION.*/ENV NODE_VERSION $VER_NODE/" |\
    docker build -t $REPO:php$VER_PHP-node$VER_NODE -

# Get the browsers layer and put that on too, and also inject some tools & metadata
( curl "$CCI_GITHUB_ROOT/php/images/$VER_PHP-fpm-buster/node-browsers-legacy/Dockerfile" 
  echo RUN sudo apt-get -y install nginx supervisor lsb-release
  echo RUN wget -O /tmp/mysql.deb 'https://dev.mysql.com/get/mysql-apt-config_0.8.16-1_all.deb'
  echo RUN sudo dpkg -i /tmp/mysql.deb
  echo RUN sudo apt update
  echo RUN sudo apt install mysql-client
  echo LABEL ver_php="$VER_PHP"
  echo LABEL ver_node="$VER_NODE"
  echo LABEL original_tag="$T:php$VER_PHP-node$VER_NODE-browsers"
  echo LABEL build_tool="https://github.com/charrington-strib/CCI-Docker-Builder"
  echo RUN echo "$BUILDINFO" \| sudo tee /buildinfo
) | \
    sed -e "s/^FROM .*$/FROM $REPO:php$VER_PHP-node$VER_NODE/" |\
    docker build -t $REPO:php$VER_PHP-node$VER_NODE-browsers -

# Tag with our private registry and push
docker tag $REPO:php$VER_PHP-node$VER_NODE-browsers $T:php$VER_PHP-node$VER_NODE-browsers
docker push $T:php$VER_PHP-node$VER_NODE-browsers


