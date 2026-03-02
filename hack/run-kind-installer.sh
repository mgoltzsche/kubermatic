#!/usr/bin/env bash

#export IMAGE_TAG="$(date +%s)"
export IMAGE_TAG="$(git describe --tags --always --match='v*')"
GIT_COMMIT_SHA="$(git rev-parse HEAD)"

set -eu

# Copy CRDs into kubermatic-operator chart directory
(echo Copying CRDs...; source hack/lib.sh && copy_crds_to_chart && set_crds_version_annotation)

set -x

# Build the installer
go build -o kubermatic-installer ./cmd/kubermatic-installer

# Build the kubermatic-operator container image
make docker-build TAGS="$IMAGE_TAG $GIT_COMMIT_SHA"

# Build the dashboard (and API) container image
# (This assumes the dashboard repo is checked out at ../dashboard)
make -C ../dashboard docker-build IMAGE_TAG=$IMAGE_TAG KUBERMATIC_EDITION=ce

# Modify the image tag within the kubermatic-operator chart values
# (This is to use the locally built image)
yq eval -i '.kubermaticOperator.image.tag=strenv(IMAGE_TAG)' ./charts/kubermatic-operator/values.yaml

# TODO: Prepare the examples directory - copy from last release? where to get the latest examples from?

# Set the tag of the locally built dashboard API container image
yq eval -i '.spec.api.dockerTag=strenv(IMAGE_TAG)' ./examples/kubermatic.example.yaml

(
	# Load locally built container images into kind once it is available
	sleep 20 # wait for kind container to initialize
	kind load docker-image quay.io/kubermatic/kubermatic:$IMAGE_TAG quay.io/kubermatic/kubermatic:$GIT_COMMIT_SHA quay.io/kubermatic/dashboard:$IMAGE_TAG --name kkp-cluster
) &

# Run the installer
./kubermatic-installer local kind

wait
