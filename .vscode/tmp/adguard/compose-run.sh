#!/bin/bash

DTSTAMP=$(date +'%Y%m%d%H%M')
TSTAMP=$(date +'%H%M$S')
#--project-name=amster-registry 
#docker network create -d bridge --attachable registry-ui-net

#docker compose up -d --rem
#docker compose registry-ui stop
#docker cp  registry-ui:/etc/nginx/nginx.conf tmp.conf
#ls -l tmp.conf

#docker.io/library/node:krypton-alpine
FROM_REPO=node-krypton-alpine
BUILDER=${FROM_REPO}
REGISTRY=reg.vados.ru
NAME=wg-easy
TYPE=rb
TAG=v15.0.3-${TYPE}
BUILD_IMAGE=${REGISTRY}/${NAME}/${NAME}
BUILD_ARG="--build-arg BUILD_DATE=${DTSTAMP}"

#docker buildx create --name ${BUILDER} --driver docker-container --use
#docker buildx use ${BUILDER}

#docker builder build --no-cache ${BUILD_ARG} -t ${BUILD_IMAGE}:${TAG} --push .

#docker-compose build --pull --no-cache --build-arg BUILD_DATE=${DTSTAMP}

#docker-compose build --pull --no-cache --push

#docker compose build --pull --no-cache ${BUILD_ARG}
#docker-compose logs registry-ui

docker compose down -v
docker compose up -d
