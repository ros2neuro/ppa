# ros2neuro PPA

Apt repository (hosted on GitHub Pages) with the Debian packages of **ros2neuro** for
**Ubuntu 24.04 (noble) + ROS 2 Jazzy**. Packages are named `ros-jazzy-ros2neuro-*`.

## Install

[ROS 2 Jazzy](https://docs.ros.org/en/jazzy/Installation.html) must already be installed.

```bash
# 1. signing key and apt source
curl -fsSL https://ros2neuro.github.io/ppa/ubuntu/ros2neuro-key.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/ros2neuro-key.gpg > /dev/null
sudo curl -fsSL -o /etc/apt/sources.list.d/ros2neuro.list https://ros2neuro.github.io/ppa/ubuntu/ros2neuro.list

# 2. install the whole stack
sudo apt update
sudo apt install ros-jazzy-ros2neuro-full

# 3. (optional) rosdep keys for ros2neuro packages
echo "yaml https://ros2neuro.github.io/ppa/ubuntu/rosdep-ros2neuro-packages.yaml" | sudo tee /etc/ros/rosdep/sources.list.d/20-ros2neuro.list
rosdep update
```

`ros-jazzy-ros2neuro-full` installs everything **except** the plugins that need a proprietary
SDK (`ros2neuro_acquisition_antneuro`, `ros2neuro_acquisition_gusbamp`), which must be built from source.
Single packages can be installed on their own, e.g. `sudo apt install ros-jazzy-ros2neuro-filters`.

Try it (no hardware):

```bash
source /opt/ros/jazzy/setup.bash
ros2 launch ros2neuro_acquisition_dummy dummy_acquisition.launch.py
```

## Build from source

The sources are in the repositories of the [ros2neuro](https://github.com/ros2neuro) organization.
Put them in the `src/` of a colcon workspace (neurodraw too, it is plain CMake) and run `colcon build`.

## Maintainers: how this repository is built

```bash
scripts/build_debs.sh      # builds every .deb in a throw-away podman container (osrf/ros:jazzy-desktop)
scripts/update_repo.sh     # Packages, Release, InRelease, Release.gpg (signs with ~/.gnupg-ros2neuro)
```

* `ONLY="ros2neuro_msgs ros2neuro_data" scripts/build_debs.sh` builds just some packages (dependencies first).
* `neurodraw` is packaged from `neurodraw-debian/debian` on commit `c47aa42` (v2.0.0).
* `ros2neuro_full/` is the metapackage.
* `liblsl-1.16.2-noble_amd64.deb` (upstream [sccn/liblsl](https://github.com/sccn/liblsl), MIT) is mirrored in `ubuntu/` because Ubuntu does not ship it and `ros2neuro_acquisition_lsl` needs it.
* `ros2neuro_decoder_py` needs `torch`/`braindecode` for the deep-learning models: install them with `pip` (they are not in apt).
* The **private** signing key is never stored here.
