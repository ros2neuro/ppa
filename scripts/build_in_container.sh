#!/bin/bash
# Runs INSIDE a throw-away container (see build_debs.sh): builds neurodraw and the
# ros2neuro packages as .deb for Ubuntu 24.04 + ROS Jazzy.
#
# Mounts: /src = workspace src/ (read only), /ppa = this repo, /out = /ppa/ubuntu (output).
# Env:    ONLY="pkg1 pkg2"  build only these ROS packages (default: all, see EXCLUDE)
#         FORCE=1           rebuild even if the .deb already exists in /out
#         NEURODRAW_COMMIT  commit of /src/neurodraw to package (default c47aa42 = main, v2.0.0)
set -euo pipefail

SRC=/src
PPA=/ppa
OUT=/out
WORK=/work
NEURODRAW_COMMIT="${NEURODRAW_COMMIT:-c47aa42}"
# proprietary-SDK plugins are not distributed; neurodraw is built separately above (colcon sees it as a cmake package)
EXCLUDE="ros2neuro_acquisition_antneuro ros2neuro_acquisition_gusbamp neurodraw"
ONLY="${ONLY:-}"

export DEBIAN_FRONTEND=noninteractive
export DEB_BUILD_OPTIONS="nocheck"
mkdir -p "$WORK" "$OUT"

echo "==> build tools and native libraries"
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    python3-bloom python3-rosdep python3-colcon-common-extensions \
    fakeroot debhelper dh-python dpkg-dev apt-utils build-essential cmake pkg-config \
    git wget ca-certificates \
    libeigen3-dev librtfilter-dev libqcustomplot-dev libfftw3-dev libyaml-cpp-dev \
    libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev libgl-dev \
    libxdffileio-dev libeegdev-dev qtbase5-dev

# liblsl is not in Ubuntu: same release used by docker/Dockerfile
if ! dpkg -s liblsl >/dev/null 2>&1; then
    wget -q https://github.com/sccn/liblsl/releases/download/v1.16.2/liblsl-1.16.2-noble_amd64.deb -O /tmp/lsl.deb
    apt-get install -y -qq /tmp/lsl.deb
fi

git config --global --add safe.directory '*'

echo "==> rosdep keys of ros2neuro"
[ -f /etc/ros/rosdep/sources.list.d/20-default.list ] || rosdep init
echo "yaml file://$OUT/rosdep-ros2neuro-packages.yaml" > /etc/ros/rosdep/sources.list.d/10-ros2neuro.list
rosdep update >/dev/null

install_deb() { apt-get install -y -qq "$@"; }

echo "==> neurodraw @ $NEURODRAW_COMMIT"
ND="$WORK/neurodraw-2.0.0"
rm -rf "$ND"; mkdir -p "$ND"
git -C "$SRC/neurodraw" archive "$NEURODRAW_COMMIT" | tar -x -C "$ND"
cp -r "$PPA/neurodraw-debian/debian" "$ND/debian"
( cd "$ND" && dpkg-buildpackage -b -uc -us )
mv "$WORK"/libneurodraw*.deb "$OUT"/
install_deb "$OUT"/libneurodraw2_*.deb "$OUT"/libneurodraw-dev_*.deb

set +u; source /opt/ros/jazzy/setup.bash; set -u

build_ros_pkg() {
    local name="$1" path="$2"
    echo "==> $name"
    # resume: a .deb already in $OUT is only installed (FORCE=1 rebuilds everything)
    local have; have=$(ls "$OUT"/ros-jazzy-"$(echo "$name" | tr _ -)"_*.deb 2>/dev/null | head -1 || true)
    if [ -n "$have" ] && [ -z "${FORCE:-}" ]; then install_deb "$have"; return 0; fi
    local w="$WORK/$name"
    rm -rf "$w"; cp -a "$path" "$w"; rm -rf "$w/build" "$w/install" "$w/log" "$w/.git"
    ( cd "$w"
      bloom-generate rosdebian --os-name ubuntu --os-version noble --ros-distro jazzy >/dev/null
      fakeroot debian/rules binary >"$WORK/$name.log" 2>&1 ) \
      || { echo "FAILED: $name (log: $WORK/$name.log)"; tail -30 "$WORK/$name.log"; return 1; }
    local deb; deb=$(ls "$WORK"/ros-jazzy-"$(echo "$name" | tr _ -)"_*.deb)
    mv "$deb" "$OUT"/
    rm -f "$WORK"/*.ddeb
    install_deb "$OUT/$(basename "$deb")"
}

if [ -n "$ONLY" ]; then LIST="$ONLY"; else
    LIST=$(colcon list --base-paths "$SRC" --topological-order --names-only)
fi

for name in $LIST; do
    case " $EXCLUDE " in *" $name "*) continue;; esac
    path=$(colcon list --base-paths "$SRC" --paths-only --packages-select "$name")
    build_ros_pkg "$name" "$path"
done

if [ -z "$ONLY" ] || [[ " $ONLY " == *" ros2neuro_full "* ]]; then
    build_ros_pkg ros2neuro_full "$PPA/ros2neuro_full"
fi
echo "==> done: $(ls "$OUT"/*.deb | wc -l) .deb in $OUT"
