INSIDE_DOCKER=$(shell [ -f /.dockerenv ] && echo 1 || echo 0 )

PWD = $(shell pwd)
ifeq ($(INSIDE_DOCKER), 0)
	DOCKER = docker run -it --rm --volume="$(PWD):/home/propeller/src" propeller 
	DOCKER_START = docker run -it --volume="$(PWD):/home/propeller/src" propeller 
else
	DOCKER = 
endif

build:
	$(DOCKER) /bin/bash /home/propeller/src/run.sh

start: docker/.build-docker
	$(DOCKER_START) /bin/bash

docker/.build-docker: docker/Dockerfile
	cd docker/ && docker build . --tag propeller
	touch docker/.build-docker