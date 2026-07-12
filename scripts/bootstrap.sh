#!/usr/bin/env bash
# bootstrap.sh — fresh machine -> populated nanos-sdk-work + toolchain + docker, ready for
# `make image64` in the NanOS repo. Idempotent: every step checks its own done-marker and
# skips. Override the workspace with SDK_WORK=... (the clean-room reproducibility gate).
#
# Layout contract: this recreates EXACTLY the directory layout the NanOS Makefile expects
# ($(SDK_WORK)/<checkout> per ports.manifest), so no Makefile paths change.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SDK_WORK="${SDK_WORK:-$HOME/Projects/nanos-sdk-work}"
ORG="${ORG:-git@github.com:NanOS-labs}"
step() { printf '\n== %s ==\n' "$*"; }

step "host prerequisites"
for c in git docker rsync curl python3; do command -v "$c" >/dev/null || { echo "MISSING: $c"; exit 1; }; done
docker info >/dev/null 2>&1 || { echo "docker daemon not running"; exit 1; }
python3 -c 'import PIL' 2>/dev/null || echo "NOTE: python3 Pillow missing (needed only for 'make assets')"
if [ "$(uname)" = Darwin ]; then
  command -v qemu-system-x86_64 >/dev/null || echo "NOTE: brew install qemu (interactive run64)"
  brew list --versions startergo/libepoxy/libepoxy startergo/angle/angle >/dev/null 2>&1 || \
    echo "NOTE: GL host stack (run64-gl) additionally needs: brew tap startergo/libepoxy startergo/angle; brew install them; then build qemu-nanos + virglrenderer-nanos (see each repo's nanos/ build script)"
fi

step "clone forks into the sdk-work layout"
mkdir -p "$SDK_WORK"
# shellcheck disable=SC2034  # base/desc are manifest columns other consumers read
grep -v '^#' "$HERE/ports.manifest" | while IFS='|' read -r name repo layout base checkout desc; do
  [ -n "$name" ] || continue
  dest="$SDK_WORK/$checkout"
  if [ -e "$dest" ]; then echo "  $checkout: present"; continue; fi
  echo "  cloning $repo -> $checkout"
  git clone -q "$ORG/$repo.git" "$dest"
  if [ "$layout" = multi ] && [ "$name" = inetutils ]; then
    ln -sfn "$dest/inetutils-services-port" "$SDK_WORK/inetutils-services-port"
  fi
done

step "special layouts (vim, ncurses, bash, netsurf)"
# vim: the Makefile mounts $(SDK_WORK)/vim (sources) AND $(SDK_WORK)/vim-port (recipe);
# the vim-nanos fork carries both (recipe files at the source root).
if [ ! -e "$SDK_WORK/vim" ]; then
  if [ ! -d "$HOME/Projects/vim-nanos/.git" ]; then git clone -q "$ORG/vim-nanos.git" "$HOME/Projects/vim-nanos"; fi
  ln -sfn "$HOME/Projects/vim-nanos" "$SDK_WORK/vim"
fi
if [ ! -e "$SDK_WORK/vim-port" ]; then
  mkdir -p "$SDK_WORK/vim-port"
  rsync -a "$SDK_WORK/vim/nxport.toml" "$SDK_WORK/vim-port/"
  [ -d "$SDK_WORK/vim/hooks" ] && rsync -a "$SDK_WORK/vim/hooks" "$SDK_WORK/vim-port/"
  [ -f "$SDK_WORK/vim/vim.install" ] && rsync -a "$SDK_WORK/vim/vim.install" "$SDK_WORK/vim-port/"
fi
# ncurses: the recipe expects $(SDK_WORK)/ncurses-port with source = dir:src; the fork tree
# IS that src (recipe files ride at its root and are copied up a level).
if [ ! -e "$SDK_WORK/ncurses-port" ]; then
  mkdir -p "$SDK_WORK/ncurses-port"
  git clone -q "$ORG/ncurses-nanos.git" "$SDK_WORK/ncurses-port/src"
  rsync -a "$SDK_WORK/ncurses-port/src/nxport.toml" "$SDK_WORK/ncurses-port/"
  [ -d "$SDK_WORK/ncurses-port/src/hooks" ] && rsync -a "$SDK_WORK/ncurses-port/src/hooks" "$SDK_WORK/ncurses-port/"
fi
# bash + netsurf build from their own fork checkouts next to the NanOS repo (BASH_FORK / NETSURF_REPO).
[ -d "$HOME/Projects/bash-nanos/.git" ]    || git clone -q "$ORG/bash-nanos.git"    "$HOME/Projects/bash-nanos"
[ -d "$HOME/Projects/netsurf-nanos/.git" ] || git clone -q "$ORG/netsurf-nanos.git" "$HOME/Projects/netsurf-nanos"
# sqlite: `make sqlite` consumes ~/Projects/sqlite-nanos.
[ -d "$HOME/Projects/sqlite-nanos/.git" ]  || git clone -q "$ORG/sqlite-nanos.git"  "$HOME/Projects/sqlite-nanos"

step "toolchain (x86_64-nanos + i686-nanos)"
if [ -x "$SDK_WORK/toolchain/bin/x86_64-nanos-gcc" ]; then
  echo "  toolchain: present"
else
  echo "  building via $HERE/build-toolchain.sh (this takes a while)"
  "$HERE/build-toolchain.sh"
fi

step "docker images"
docker image inspect nanos-sdk-dev:latest >/dev/null 2>&1 || docker build -t nanos-sdk-dev:latest "$HERE"
echo "  (the nanos-build image is built by the NanOS repo itself: make docker-image)"

step "done — next steps (inside the NanOS checkout)"
cat <<'EOF'
  make docker-image
  make ARCH=x86_64 zlib openssl ncurses            # library layer
  make ARCH=x86_64 toybox sudo grep bzip2          # base userland
  make ARCH=x86_64 ping wget inetd httpd udhcpc dropbear   # network layer
  make ARCH=x86_64 vim htop git sqlite bash        # apps
  make ARCH=x86_64 libpng libjpeg && make netsurf  # browser
  make libdrm mesa gles2info glkms nwm-gl          # GL userspace
  make externals && make image64                   # the image
  # host GL stack (macOS, optional): qemu-nanos/nanos/build-qemu.sh + virglrenderer-nanos/nanos/build-virgl.sh
EOF
