#!/bin/bash

sudo add-apt-repository ppa:cncf-buildpacks/pack-cli
sudo apt-get update
sudo apt-get install pack-cli
cd app
pack build $DOCKER_USERNAME/cloudbox:latest --builder paketobuildpacks/builder:base