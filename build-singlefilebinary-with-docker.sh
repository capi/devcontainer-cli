#!/usr/bin/env bash
set -euo pipefail

# Build a single-file Linux x64 devcontainer CLI binary inside Docker.
# Produces: ./build/devcontainer owned by the invoking user.
# The repository working tree is mounted read-only into the container so
# no files in the checkout are modified by this script.

usage() {
  cat <<EOF
Usage: $0 [--image node:18]

Builds ./build/devcontainer (linux x64). The script requires Docker.
EOF
}

IMAGE=${1:-node:18}

# Allow caller to override UID/GID for chown inside container
HOST_UID=${HOST_UID:-$(id -u)}
HOST_GID=${HOST_GID:-$(id -g)}

OUT_DIR="$PWD/build_output"
mkdir -p "$OUT_DIR"

echo "Building devcontainer binary for linux/x64 using image: $IMAGE"

# Run build inside Docker. Mount repository read-only to avoid modifying working tree.
# Copy the repo inside the container to a writable location and perform npm install and build there.
# Output the final binary to the mounted OUT_DIR which is the only path written on the host.

docker run --rm \
  -e HOST_UID="$HOST_UID" -e HOST_GID="$HOST_GID" \
  -v "$PWD":/src:ro \
  -v "$OUT_DIR":/out \
  -w /tmp/src \
  "$IMAGE" bash -lc '
set -euo pipefail

apt-get update -qq
apt-get install -y -qq python3 make g++ git curl ca-certificates

# Copy workspace to a writable location inside the container
rm -rf /tmp/src
cp -a /src /tmp/src
cd /tmp/src

# Install dependencies and build
npm install --silent
npm run compile-prod --silent

# Install pkg and produce single-file executable
npm i -g --silent pkg
pkg . --targets node18-linux-x64 --output /out/devcontainer
chmod +x /out/devcontainer

# Ensure the file in /out is owned by the host user
chown "$HOST_UID":"$HOST_GID" /out/devcontainer
'

echo "Binary written to: $OUT_DIR/devcontainer"
