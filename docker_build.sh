#!/bin/bash

set -e

help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --target    Specify the target binary to build (default: controller)"
  echo "  --repo      Specify the Docker repository (default: docker.hops.works/gcr.io/knative-releases/knative.dev/serving/cmd/)"
  echo "  --platform  Specify the target platform (default: linux/amd64)"
  echo "  --push      Specify whether to push the image (true/false, default: false)"
  echo "  --help      Display this help message"
  echo ""
  echo "Example:"
  echo "  $0 --target webhook --repo myrepo/ --platform linux/arm64 --push true"
  exit 0
}

# Define the target path
TARGET=controller
REPO=docker.hops.works/gcr.io/knative-releases/knative.dev/serving/cmd/
PLATFORM=linux/amd64
PUSH=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --target) TARGET="$2"; shift ;;
    --repo) REPO="$2"; shift ;;
    --platform) PLATFORM="$2"; shift ;;
    --push) PUSH="$2"; shift ;;
    *) help; exit 1 ;;
  esac
  shift
done

echo "Building Docker image for target: $TARGET"

# Generate the Dockerfile
cat <<EOF > Dockerfile
# Use the official Go image to build the binary
FROM golang:1.21 as builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build the binary
ARG BUUI=./cmd/$TARGET
RUN mkdir -p /app/bin
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/bin/$TARGET ./cmd/$TARGET

# Use a minimal base image for the final container
FROM gcr.io/distroless/static:nonroot

# Copy the binary from the builder stage
COPY --from=builder /app/bin/$TARGET /bin/$TARGET

# Set the binary as the entrypoint
ENTRYPOINT ["/bin/$TARGET"]
EOF

# Build the Docker image
VERSION=$(cat VERSION)
TAG="$REPO$TARGET:v${VERSION}"
docker build --progress=plain --no-cache --platform=$PLATFORM -t $TAG .
if [ "$PUSH" = true ]; then
  # Push the Docker image to the repository
  docker push "$REPO$TARGET:${VERSION}"
fi