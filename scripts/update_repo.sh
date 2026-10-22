#!/bin/bash
# Rebuilds the flat apt index of ubuntu/ and signs it.
# The PRIVATE key lives in $GNUPGHOME (default ~/.gnupg-ros2neuro), never in this repo.
set -euo pipefail
PPA=$(cd "$(dirname "$0")/.." && pwd)
export GNUPGHOME="${GNUPGHOME:-$HOME/.gnupg-ros2neuro}"
KEY="${KEY:-ros2neuro PPA}"

cd "$PPA/ubuntu"
rm -f Packages Packages.gz Release Release.gpg InRelease
dpkg-scanpackages --multiversion . /dev/null > Packages
gzip -k -f Packages
apt-ftparchive release . > Release
gpg --batch --yes --local-user "$KEY" -abs -o Release.gpg Release
gpg --batch --yes --local-user "$KEY" --clearsign -o InRelease Release
gpg --verify Release.gpg Release
echo "index updated: $(grep -c '^Package:' Packages) packages"
