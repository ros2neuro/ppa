#!/bin/bash
# Host wrapper: builds the .deb inside a throw-away podman container, so nothing is
# installed in the ros2neuro dev container (ros-jazzy-ros2neuro-* would mix with the workspace).
#
#   scripts/build_debs.sh                              all packages
#   ONLY="ros2neuro_msgs ros2neuro_data" scripts/build_debs.sh   pilot run
set -euo pipefail
PPA=$(cd "$(dirname "$0")/.." && pwd)
SRC=$(dirname "$PPA")
IMAGE="${IMAGE:-docker.io/osrf/ros:jazzy-desktop}"

podman run --rm \
    -v "$SRC":/src:ro \
    -v "$PPA":/ppa \
    -v "$PPA/ubuntu":/out \
    -e ONLY="${ONLY:-}" -e FORCE="${FORCE:-}" -e NEURODRAW_COMMIT="${NEURODRAW_COMMIT:-c47aa42}" \
    "$IMAGE" bash /ppa/scripts/build_in_container.sh
