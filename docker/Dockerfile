# ROS 2 Jazzy + ros2neuro, installed from the ros2neuro PPA.
#
#   docker build -t ros2neuro docker/          # or: podman build -t ros2neuro docker/
#   docker run -it --rm ros2neuro ros2 launch ros2neuro_acquisition_dummy dummy_acquisition.launch.py
#
# See "Docker" in the README for how to open the feedback window (wheel / bars) from the container.
FROM docker.io/library/ros:jazzy-ros-base

# where the ros2neuro apt repository is served (override to test another location)
ARG PPA_URL=https://ros2neuro.github.io/ppa/ubuntu/

ENV DEBIAN_FRONTEND=noninteractive

# libgl1-mesa-dri / libglx-mesa0: OpenGL in software (LIBGL_ALWAYS_SOFTWARE=1) when no GPU is passed in;
# xvfb + xauth: run the feedback without a screen (tests, CI)
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl gnupg ca-certificates \
 && curl -fsSL "${PPA_URL}ros2neuro-key.asc" | gpg --dearmor -o /etc/apt/trusted.gpg.d/ros2neuro-key.gpg \
 && echo "deb [signed-by=/etc/apt/trusted.gpg.d/ros2neuro-key.gpg] ${PPA_URL} ./" > /etc/apt/sources.list.d/ros2neuro.list \
 && apt-get update \
 && apt-get install -y ros-jazzy-ros2neuro-full libgl1-mesa-dri libglx-mesa0 xvfb xauth \
 && rm -rf /var/lib/apt/lists/*

# Distrobox: this image can also be used with `distrobox create --image ...`. Old Distrobox versions try to install
# libgl1-mesa-glx and libegl1-mesa, which do not exist on Ubuntu 24.04 (empty placeholder packages make that step succeed),
# and need passwordless sudo for the image's user (the same UID as the host user in most cases).
RUN apt-get update && apt-get install -y --no-install-recommends equivs sudo \
 && cd /tmp \
 && printf 'Section: misc\nPriority: optional\nStandards-Version: 3.9.2\nPackage: libgl1-mesa-glx\nDescription: placeholder\n' > fake-glx \
 && printf 'Section: misc\nPriority: optional\nStandards-Version: 3.9.2\nPackage: libegl1-mesa\nDescription: placeholder\n' > fake-egl \
 && equivs-build fake-glx && equivs-build fake-egl \
 && dpkg -i libgl1-mesa-glx_1.0_all.deb libegl1-mesa_1.0_all.deb \
 && rm -f /tmp/*.deb /tmp/fake-* \
 && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && chmod 440 /etc/sudoers.d/ubuntu \
 && rm -rf /var/lib/apt/lists/*

# the ros image's entrypoint already sources /opt/ros/jazzy/setup.bash; an interactive bash needs it too
RUN echo "source /opt/ros/jazzy/setup.bash" >> /etc/bash.bashrc

# not root: files written in mounted folders (recordings) belong to the user, not to root
USER ubuntu
WORKDIR /home/ubuntu
CMD ["bash"]
