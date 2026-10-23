#!/bin/bash
# Builds docker/Dockerfile and checks that ros2neuro works inside the image:
#   1. the packages are installed
#   2. the dummy acquisition starts
#   3. ros2neuro_devel_test: the wheel and the bars feedback start (xvfb + software OpenGL)
#
#   ENGINE=podman scripts/test_docker.sh        (default)
#   ENGINE=docker scripts/test_docker.sh
#   PPA_URL=http://... scripts/test_docker.sh   test another location of the apt repository
#   LOCAL=1 scripts/test_docker.sh              test the local ubuntu/ folder (served on http://127.0.0.1:8765/),
#                                               e.g. before pushing or while the repository is private
set -uo pipefail
ENGINE="${ENGINE:-podman}"
IMAGE="${IMAGE:-ros2neuro-ppa-test}"
PPA=$(cd "$(dirname "$0")/.." && pwd)

build_net=()
if [ -n "${LOCAL:-}" ]; then
    python3 -m http.server 8765 --bind 127.0.0.1 --directory "$PPA" > /dev/null 2>&1 &
    server_pid=$!
    trap 'kill "$server_pid" 2>/dev/null' EXIT
    sleep 1
    PPA_URL="http://127.0.0.1:8765/ubuntu/"
    build_net=(--network host)          # the build must reach 127.0.0.1 of this machine
fi

failures=0
ok()   { echo "  [ OK ] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }

echo "== build ($ENGINE)"
build_args=()
[ -n "${PPA_URL:-}" ] && build_args+=(--build-arg "PPA_URL=$PPA_URL")
$ENGINE build "${build_net[@]}" "${build_args[@]}" -t "$IMAGE" -f "$PPA/docker/Dockerfile" "$PPA/docker" > /tmp/test_docker_build.log 2>&1 \
    || { echo "build failed, see /tmp/test_docker_build.log"; tail -20 /tmp/test_docker_build.log; exit 1; }

run() { $ENGINE run --rm "$IMAGE" bash -c "$1" 2>&1; }

echo "== 1) packages"
n=$(run 'ros2 pkg list | grep -c ros2neuro' | tail -1)
[ "${n:-0}" -ge 39 ] && ok "$n ros2neuro packages installed" || fail "only ${n:-0} ros2neuro packages"

echo "== 2) dummy acquisition"
out=$(run 'timeout 8 ros2 launch ros2neuro_acquisition_dummy dummy_acquisition.launch.py')
echo "$out" | grep -q "Started device 'dummy_device'" && ok "dummy_device started" || { fail "dummy_device not started"; echo "$out" | tail -15; }
echo "$out" | grep -q "\[ERROR\]" && { fail "errors in the dummy log"; echo "$out" | grep "\[ERROR\]" | head -5; } || ok "no [ERROR] lines"

echo "== 3) ros2neuro_devel_test"
for kind in wheel:Wheel bars:Bar; do
    launcher="${kind%%:*}"; plugin="${kind##*:}"
    out=$(run "LIBGL_ALWAYS_SOFTWARE=1 timeout 40 xvfb-run -a -s '-screen 0 1280x720x24' ros2 launch ros2neuro_devel_test gaussian_${launcher}.launch.xml protocol:=calibration record:=false")
    echo "$out" | grep -q "Feedback configured: plugin 'ros2neuro::feedback::${plugin}'" \
        && ok "gaussian_${launcher}: feedback ${plugin} configured" || { fail "gaussian_${launcher}: feedback ${plugin} not configured"; echo "$out" | tail -15; }
    echo "$out" | grep -q "Engine is up" && ok "gaussian_${launcher}: neurodraw engine up" || fail "gaussian_${launcher}: neurodraw engine not up"
    echo "$out" | grep -q "\[ERROR\]" && { fail "gaussian_${launcher}: errors in the log"; echo "$out" | grep "\[ERROR\]" | head -5; } || ok "gaussian_${launcher}: no [ERROR] lines"
done

echo
[ "$failures" -eq 0 ] && echo "ALL CHECKS PASSED ($ENGINE)" || echo "$failures CHECK(S) FAILED ($ENGINE)"
exit "$failures"
