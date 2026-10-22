#!/bin/bash
# Clean-room test: Ubuntu 24.04 + ROS apt repo + this PPA, install ros-jazzy-ros2neuro-full and run it.
#
#   scripts/test_install.sh              test the LOCAL ubuntu/ folder (file:// source)
#   REPO_URL=https://ros2neuro.github.io/ppa/ubuntu/ scripts/test_install.sh   test the published PPA
#
# Runs in a throw-away podman container, nothing is installed on the host.
# After the install it starts (1) the dummy acquisition and (2) the neurodraw wheel feedback
# (devel_test gaussian_wheel, calibration) under xvfb with software OpenGL.
set -euo pipefail
PPA=$(cd "$(dirname "$0")/.." && pwd)

podman run -i --rm -v "$PPA/ubuntu":/repo:ro -e REPO_URL="${REPO_URL:-}" \
    docker.io/library/ubuntu:24.04 bash -s <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq curl gnupg ca-certificates >/dev/null
curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu noble main" > /etc/apt/sources.list.d/ros2.list

if [ -n "$REPO_URL" ]; then            # same steps as the README
    curl -fsSL "${REPO_URL}ros2neuro-key.asc" | gpg --dearmor > /etc/apt/trusted.gpg.d/ros2neuro-key.gpg
    curl -fsSL -o /etc/apt/sources.list.d/ros2neuro.list "${REPO_URL}ros2neuro.list"
else
    gpg --dearmor < /repo/ros2neuro-key.asc > /etc/apt/trusted.gpg.d/ros2neuro-key.gpg
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/ros2neuro-key.gpg] file:///repo ./" > /etc/apt/sources.list.d/ros2neuro.list
fi
apt-get update 2>&1 | grep -iE "ros2neuro|/repo|err|warn" || true
apt-get install -y ros-jazzy-ros2neuro-full 2>&1 | tail -3
apt-get install -y -qq xvfb libgl1-mesa-dri libglx-mesa0 >/dev/null

set +u; source /opt/ros/jazzy/setup.bash
echo "== ros2neuro packages installed: $(ros2 pkg list | grep -c ros2neuro)"

echo "== 1) dummy acquisition"
timeout 6 ros2 launch ros2neuro_acquisition_dummy dummy_acquisition.launch.py 2>&1 | grep -E "Started device|ERROR|error" || echo "NO 'Started device' line"

echo "== 2) wheel feedback (xvfb, software GL)"
export LIBGL_ALWAYS_SOFTWARE=1
timeout 40 xvfb-run -a -s "-screen 0 1280x720x24" \
    ros2 launch ros2neuro_devel_test gaussian_wheel.launch.xml protocol:=calibration 2>&1 \
    | grep -iE "error|fail|cannot|not found|exception|Loaded plugin|process started|feedback" | head -40 || true
echo "== done"
EOF
