# nanos-sdk — the i686-nanos cross toolchain + port tooling, frozen into an image.
# Builds binutils+gcc for the i686-nanos target (build-toolchain.sh), picolibc, and the
# autotools/cmake/meson/pkg-config needed to drive ports. The sysroot link bits + mknx are
# injected at use time from a built NanOS checkout via `sync-sysroot` (libc.ndl tracks the kernel).
FROM debian:trixie-slim
ENV PREFIX=/opt/i686-nanos
ENV PATH="${PREFIX}/bin:${PATH}"
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates wget make build-essential bison flex texinfo \
        libgmp-dev libmpc-dev libmpfr-dev \
        autoconf automake libtool pkgconf cmake meson ninja-build python3 git xz-utils \
    && rm -rf /var/lib/apt/lists/*
COPY toolchain /sdk/toolchain
COPY build-toolchain.sh /sdk/build-toolchain.sh
RUN WORK=/tmp/tc PREFIX=${PREFIX} /sdk/build-toolchain.sh all && rm -rf /tmp/tc
# picolibc headers/lib for the sysroot (i686-elf build works for the i686 machine).
ARG PICOLIBC_VERSION=1.8.6
COPY picolibc-i686-elf.txt /tmp/pico.txt
RUN git clone --depth 1 --branch "${PICOLIBC_VERSION}" https://github.com/picolibc/picolibc /tmp/picolibc \
    && cd /tmp/picolibc && meson setup build --cross-file /tmp/pico.txt \
        -Dprefix=/opt/picolibc/i686-elf -Dincludedir=include -Dlibdir=lib \
        -Dmultilib=false -Dpicocrt=false -Dpicolib=true -Dsemihost=false -Dposix-console=true \
        -Dtests=false -Dformat-default=integer -Dthread-local-storage=false \
    && ninja -C build && ninja -C build install && cd / && rm -rf /tmp/picolibc /tmp/pico.txt
COPY . /sdk
RUN ln -s /sdk/port/nanos-port /usr/local/bin/nanos-port \
    && ln -s /sdk/sysroot/sync-sysroot /usr/local/bin/sync-sysroot
WORKDIR /work
