#!/bin/bash

if [ -z "$DOCKER_USERNAME" ]; then
  echo "DOCKER_USERNAME is not set!"
  exit 1
fi

sudo add-apt-repository ppa:cncf-buildpacks/pack-cli
sudo apt-get update
sudo apt-get install pack-cli
cd app
pack build stefnie/cloudbox:latest --builder paketobuildpacks/builder:base