# Clean Ubuntu 24.04 for trying the ros2neuro PPA with a graphical window through Distrobox.
#
#   podman build -t ppa_test_image -f test/ppa-test.Containerfile test/
#   mkdir -p ~/ppa-test-home
#   distrobox create --name ppa-test --image localhost/ppa_test_image --home ~/ppa-test-home
#
# Old Distrobox versions (1.4.x) try to install libgl1-mesa-glx and libegl1-mesa, which do not exist
# on Ubuntu 24.04: empty placeholder packages make that step succeed (the real Mesa libraries come with the
# ros2neuro packages' dependencies).
FROM docker.io/library/ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends equivs sudo curl gnupg ca-certificates \
 && cd /tmp \
 && printf 'Section: misc\nPriority: optional\nStandards-Version: 3.9.2\nPackage: libgl1-mesa-glx\nDescription: placeholder\n' > fake-glx \
 && printf 'Section: misc\nPriority: optional\nStandards-Version: 3.9.2\nPackage: libegl1-mesa\nDescription: placeholder\n' > fake-egl \
 && equivs-build fake-glx && equivs-build fake-egl \
 && dpkg -i libgl1-mesa-glx_1.0_all.deb libegl1-mesa_1.0_all.deb \
 && rm -f /tmp/*.deb /tmp/fake-* \
 && rm -rf /var/lib/apt/lists/*

# The image's default user is "ubuntu" (UID 1000, the same as the host user): Distrobox cannot create its own
# user and writes its passwordless-sudo rule for the host user name, which then matches nobody.
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && chmod 440 /etc/sudoers.d/ubuntu
