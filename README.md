# ros2neuro PPA

Apt repository (hosted on GitHub Pages) with the Debian packages of **ros2neuro**, the modular ROS 2 stack for
neurophysiological signal acquisition, processing, decoding and closed-loop BCI applications.

| | |
|---|---|
| **Ubuntu** | 24.04 (noble), amd64 |
| **ROS 2** | Jazzy |
| **Packages** | `ros-jazzy-ros2neuro-*` and the `ros-jazzy-ros2neuro-full` metapackage |
| **Repository** | `https://ros2neuro.github.io/ppa/ubuntu/` |

Other Ubuntu or ROS versions are not supported: the packages are built for noble and depend on `ros-jazzy-*`.

## Install

### 1. ROS 2 Jazzy

ROS 2 Jazzy must be available. If it is already installed (see the
[official guide](https://docs.ros.org/en/jazzy/Installation.html)) skip this step. On a plain Ubuntu 24.04 it is
enough to add the ROS 2 apt source; the ros2neuro packages pull in the ROS packages they need:

```bash
sudo apt update && sudo apt install -y curl gnupg ca-certificates
sudo curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu noble main" | sudo tee /etc/apt/sources.list.d/ros2.list
```

### 2. The ros2neuro repository

```bash
curl -fsSL https://ros2neuro.github.io/ppa/ubuntu/ros2neuro-key.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/ros2neuro-key.gpg > /dev/null
sudo curl -fsSL -o /etc/apt/sources.list.d/ros2neuro.list https://ros2neuro.github.io/ppa/ubuntu/ros2neuro.list
```

### 3. Install

```bash
sudo apt update
sudo apt install ros-jazzy-ros2neuro-full
```

`ros-jazzy-ros2neuro-full` installs everything **except** the acquisition plugins that need a proprietary SDK
(`ros2neuro_acquisition_antneuro`, `ros2neuro_acquisition_gusbamp`), which must be built from source.
Single packages can be installed on their own, e.g. `sudo apt install ros-jazzy-ros2neuro-filters`.

### 4. (Optional) rosdep keys

To let `rosdep` resolve the ros2neuro packages when you build your own workspace:

```bash
echo "yaml https://ros2neuro.github.io/ppa/ubuntu/rosdep-ros2neuro-packages.yaml" | sudo tee /etc/ros/rosdep/sources.list.d/20-ros2neuro.list
rosdep update
```

### Update and remove

```bash
sudo apt update && sudo apt upgrade        # new versions of the ros2neuro packages
sudo apt remove ros-jazzy-ros2neuro-full   # remove the metapackage (add 'autoremove' for its dependencies)
```

## Try it (no hardware)

```bash
source /opt/ros/jazzy/setup.bash

# dummy acquisition (sinusoidal EEG/EMG + trigger, no window)
ros2 launch ros2neuro_acquisition_dummy dummy_acquisition.launch.py

# whole chain on a recorded GDF, with the feedback window: the wheel or the bars
ros2 launch ros2neuro_devel_test gaussian_wheel.launch.xml protocol:=calibration record:=false
ros2 launch ros2neuro_devel_test gaussian_bars.launch.xml  protocol:=calibration record:=false
```

`protocol` is `calibration`, `evaluation` (default) or `control`. `record:=false` skips the recorder: by default the
launchers write the GDF in a folder inside the installation prefix, which a normal user cannot write; to record, pass a
folder of yours with `recordings_dir:=$HOME/recordings`. If the window flickers or does not open, try
`LIBGL_ALWAYS_SOFTWARE=1` in front of the command. The session ends by itself when the protocol is over.

More launchers (QDA, EEGNet, 4 classes, with the rest class, ...) are described in the README of
[ros2neuro_devel_test](https://github.com/ros2neuro/ros2neuro_devel_test).

### Not in apt

`ros2neuro_decoder_py` (deep-learning models) needs `torch` and `braindecode`; install them with `pip` if you use it.
`liblsl` (needed by `ros2neuro_acquisition_lsl`) is not in Ubuntu: this repository ships the upstream
[sccn/liblsl](https://github.com/sccn/liblsl) package (MIT) and apt installs it automatically.

## Try it in a clean container

To test the installation without touching your system, use a throw-away Ubuntu 24.04 with
[Distrobox](https://distrobox.it/) (it shares the display, so the feedback window opens). The image is built from
[`test/ppa-test.Containerfile`](test/ppa-test.Containerfile), which works around two quirks of old Distrobox versions:

```bash
podman build -t ppa_test_image -f test/ppa-test.Containerfile test/
distrobox create --name ppa-test --image localhost/ppa_test_image      # add --nvidia for NVIDIA GPUs
distrobox enter ppa-test
# ... then follow "Install" and "Try it" above
distrobox rm -f ppa-test                                               # when done
```

Do not `source` another ROS 2 workspace inside this container: the home directory is shared with the host.

## Build from source

The sources are in the repositories of the [ros2neuro](https://github.com/ros2neuro) organization.
Put them in the `src/` of a colcon workspace (`neurodraw` too, it is plain CMake) and run `colcon build`.

## Maintainers

### Build the packages

```bash
scripts/build_debs.sh      # builds every .deb in a throw-away podman container (osrf/ros:jazzy-desktop)
scripts/update_repo.sh     # Packages, Release, InRelease, Release.gpg (signs with ~/.gnupg-ros2neuro)
```

* The `.deb` are built from the working trees found next to this folder (`../ros2neuro_*`), so commit, tag and update
  the sources first. `ONLY="ros2neuro_msgs ros2neuro_data" scripts/build_debs.sh` builds just some packages
  (dependencies first); a `.deb` already in `ubuntu/` is only installed, use `FORCE=1` to rebuild it.
* Nothing is installed on the host: the ros2neuro packages are installed only inside the build container.
* `neurodraw` is packaged from `neurodraw-debian/debian` on commit `c47aa42` (v2.0.0) of the `neurodraw` repository.
* `ros2neuro_full/` is the metapackage; `ros2neuro_acquisition_antneuro` and `ros2neuro_acquisition_gusbamp` are excluded.
* `ubuntu/rosdep-ros2neuro-packages.yaml` maps each `ros2neuro_*` rosdep key to its `ros-jazzy-*` package.

### Test

```bash
scripts/test_install.sh                                                   # the local ubuntu/ folder
REPO_URL=https://ros2neuro.github.io/ppa/ubuntu/ scripts/test_install.sh  # the published repository
```

The script installs `ros-jazzy-ros2neuro-full` in a clean Ubuntu 24.04 container and checks that the dummy acquisition
and the wheel feedback (under xvfb) start.

### Publish

Commit and push `ubuntu/` to `main`; GitHub Pages (Settings → Pages → branch `main`, folder `/`) serves it. The
repository must stay **public** for the site to be reachable: if it is made private, Pages stops serving and `apt update`
fails with 404.

### Signing key

* The repository is signed with a dedicated GPG key (`ros2neuro PPA <forin.paolo98@gmail.com>`); the public part is
  `ubuntu/ros2neuro-key.asc` (armored) and `ubuntu/ros2neuro-key.gpg`.
* The **private** key lives in `~/.gnupg-ros2neuro` and, as a backup, in `private/` (ignored by `.gitignore`). It must
  never be committed or pushed: whoever has it can sign packages as ros2neuro.
