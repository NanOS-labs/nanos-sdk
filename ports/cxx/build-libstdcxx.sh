#!/bin/sh
# Build a HOSTED libstdc++ (static) for x86_64-nanos against picolibc, standalone from the gcc
# source tree (avoids rebuilding binutils+gcc). Runs in nanos-sdk-dev with the x86_64-nanos
# toolchain on PATH. Installs headers + libstdc++.a/libsupc++.a into the x86_64-nanos sysroot so
# Mesa's C++ (src/compiler/glsl) can build. --with-newlib: picolibc is newlib-like.
set -e
SRC=/work/cxx/gcc-14.2.0
SYSROOT=/work/toolchain/x86_64-nanos
PICO=/opt/picolibc/x86_64-elf
B=/work/cxx/build-libstdcxx
rm -rf "$B"; mkdir -p "$B"; cd "$B"

# picolibc + libc-glue headers so libstdc++'s configure probes + compiles see a C library.
INC="-isystem $PICO/include -isystem $SYSROOT/include"
export CC="x86_64-nanos-gcc"
export CXX="x86_64-nanos-g++"
export CFLAGS="$INC -O2"
export CXXFLAGS="$INC -O2 -fno-exceptions -fno-rtti"
export CPPFLAGS="$INC"
export CC_FOR_TARGET="$CC" CXX_FOR_TARGET="$CXX"

"$SRC/libstdc++-v3/configure" \
  --host=x86_64-nanos --build="$(uname -m)-linux-gnu" \
  --prefix="$SYSROOT" --disable-shared --enable-static \
  --with-newlib --disable-libstdcxx-pch --disable-libstdcxx-verbose \
  --disable-nls --disable-wchar_t --disable-tls \
  --enable-threads=posix --enable-libstdcxx-threads 2>&1 | tail -20

[ -n "$CONFIGURE_ONLY" ] && { echo "== libstdc++ configure OK =="; exit 0; }
make -j"$(nproc)" 2>&1 | tail -25
make install
echo "== libstdc++ installed into $SYSROOT =="
ls "$SYSROOT/lib/libstdc++.a" "$SYSROOT/lib/libsupc++.a" 2>/dev/null
