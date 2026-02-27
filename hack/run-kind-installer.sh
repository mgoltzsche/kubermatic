#!/usr/bin/env bash

set -eux

# Copy CRDs into kubermatic-operator chart directory
source hack/lib.sh
copy_crds_to_chart
set_crds_version_annotation

# Build the installer
go build -o kubermatic-installer ./cmd/kubermatic-installer

# Build the kubermatic-operator container image
make docker-build

# Build the dashboard (and API) container image
# (This assumes the dashboard repo is checked out at ../dashboard)
make -C ../dashboard docker-build IMAGE_TAG=NA KUBERMATIC_EDITION=ce

# Modify the image tag within the kubermatic-operator chart values
# (This is to use the locally built image)
yq eval -i '.kubermaticOperator.image.tag="latestbuild"' ./charts/kubermatic-operator/values.yaml

# TODO: Prepare the examples directory - copy from last release? where to get the latest examples from?

# Set the tag of the locally built dashboard API container image
yq eval -i '.spec.api.dockerTag="NA"' ./examples/kubermatic.example.yaml

(
	# Load locally built container images into kind once it is available
	sleep 20 # wait for kind container to initialize
	kind load docker-image quay.io/kubermatic/kubermatic:latestbuild quay.io/kubermatic/dashboard:NA --name kkp-cluster
) &

# Run the installer
./kubermatic-installer local kind

wait
