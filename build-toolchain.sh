#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# build-toolchain.sh — build a native nanos cross toolchain (binutils + gcc) from source.
# TARGET selects the triplet (default x86_64-nanos; TARGET=i686-nanos for the retired 32-bit one).
# Run inside a container with build deps (the nanos-build image has them). Installs to $PREFIX.
set -e
BINUTILS_VERSION="${BINUTILS_VERSION:-2.43}"
GCC_VERSION="${GCC_VERSION:-14.2.0}"
TARGET="${TARGET:-x86_64-nanos}"          # cut-over default; i686-nanos retired (spec §0.1)
PREFIX="${PREFIX:-/opt/$TARGET}"
WORK="${WORK:-/opt/nanos-sdk-build}"
SDK="$(cd "$(dirname "$0")" && pwd)"
JOBS="$(nproc)"
PHASE="${1:-all}"

mkdir -p "$WORK"; cd "$WORK"
[ -d "binutils-$BINUTILS_VERSION" ] || { wget -q "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.xz"; tar xf "binutils-$BINUTILS_VERSION.tar.xz"; }
[ -d "gcc-$GCC_VERSION" ] || { wget -q "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz"; tar xf "gcc-$GCC_VERSION.tar.xz"; }

sh "$SDK/toolchain/patch.sh" "$WORK/binutils-$BINUTILS_VERSION" "$WORK/gcc-$GCC_VERSION" "$SDK/toolchain"
[ "$PHASE" = patch ] && { echo "== patch-only done =="; exit 0; }

export PATH="$PREFIX/bin:$PATH"

echo "== binutils =="
rm -rf build-binutils; mkdir build-binutils; cd build-binutils
../binutils-$BINUTILS_VERSION/configure --target=$TARGET --prefix=$PREFIX \
	--with-sysroot --disable-nls --disable-werror
[ "$PHASE" = configure-binutils ] && { echo "== binutils configure OK =="; exit 0; }
make -j"$JOBS"; make install
cd "$WORK"
[ "$PHASE" = binutils ] && { echo "== binutils done =="; exit 0; }

echo "== gcc (all-gcc + libgcc) =="
rm -rf build-gcc; mkdir build-gcc; cd build-gcc
../gcc-$GCC_VERSION/configure --target=$TARGET --prefix=$PREFIX \
	--disable-nls --enable-languages=c,c++ --without-headers
make -j"$JOBS" all-gcc all-target-libgcc
make install-gcc install-target-libgcc
echo "== toolchain installed to $PREFIX =="
"$PREFIX/bin/$TARGET-gcc" --version | head -1
"$PREFIX/bin/$TARGET-gcc" -dumpmachine
