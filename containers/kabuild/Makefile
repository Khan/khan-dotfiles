REPO=gcr.io/khan-internal-services/services
IMAGE=${REPO}/kabuild-image
CURRENT_IMAGE_TAG:=$(shell skaffold build -q --dry-run | jq '.builds[0].tag' | tr -d '"')
ifeq (${VER},)
CLEAN_IMAGE_TAG:=$(shell echo ${CURRENT_IMAGE_TAG} | sed 's/-dirty//')
else
CLEAN_IMAGE_TAG:=${IMAGE}:${VER}
endif
ifneq (${CURRENT_IMAGE_TAG},${CLEAN_IMAGE_TAG})
PULL_POLICY=always
else
PULL_POLICY=missing
endif

KAROOT=~/khan

.PHONY: help
help:
	@echo "  build: Build the container with cloudbuild"
	@echo "  docker_build: Build the container locally with docker"
	@echo "  repo_list: List the images we've pushed so far"
	@echo "  run_dirty: Run the container most recently built (for debugging changes)"
	@echo "  run: Run what we think is the most recent version of the container"
	@echo "  run VER=...: Run a specific version of the container"
	@echo "  current_tag: The current tag that is/was built"
	@echo "  current image: Full image that is/was built"

# The current image name (and tag)
.PHONY: current_image
current_image:
	@echo ${CURRENT_IMAGE_TAG}

# The current tag that will be built
.PHONY: current_tag
current_tag:
	@echo ${CURRENT_IMAGE_TAG} | sed 's/.*://'

# Run what we think is the most recent non-dirty image (most recent tag)
.PHONY: run
run:
	@echo "Running ${CLEAN_IMAGE_TAG}"
	@echo "Mapping private key ~/.ssh/id_rsa"
	@echo "Mapping ~/khan"
	@docker run --rm -it \
		-v ~/.ssh/id_rsa:/home/kabuild/.ssh/id_rsa \
		-v ${KAROOT}:/home/kabuild/khan \
		${CLEAN_IMAGE_TAG} bash -l

# Run the current image whether dirty or clean
# This is the command to use when testing changes
.PHONY: run_dirty
run_dirty:
	@echo "Running ${CURRENT_IMAGE_TAG}"
	@echo "Mapping private key ~/.ssh/id_rsa"
	@echo "Mapping ~/khan"
	@docker run -it --rm --pull ${PULL_POLICY} \
		-v ~/.ssh/id_rsa:/home/kabuild/.ssh/id_rsa \
		-v ${KAROOT}:/home/kabuild/khan \
		${CURRENT_IMAGE_TAG} bash -l

.PHONY: docker_build
docker_build:
	skaffold build

.PHONY: build
build:
	skaffold build -p cloudbuild

.PHONY: repo_list
repo_list:
	gcloud container images list-tags ${IMAGE}
