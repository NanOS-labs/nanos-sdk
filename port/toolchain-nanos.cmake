# CMake cross file for NanOS. Use: cmake -DCMAKE_TOOLCHAIN_FILE=.../toolchain-nanos.cmake
#
# ARCH-AWARE via NX_HOST (mirrors the autotools path in nanos-port, which passes --host=$NX_HOST):
# the i686-nanos default keeps the original 32-bit flow byte-for-byte; setting NX_HOST=x86_64-nanos
# (NanOS `make ARCH=x86_64 <port>`) retargets the cross compiler/ar/ranlib at the 64-bit toolchain
# and injects the NanOS x86_64 user ABI cflags + the nx-dllimport.h DATA-import shim, exactly like
# the autotools ports (zlib/ncurses/libpng) do via CFLAGS + post_configure.
if(DEFINED ENV{NX_HOST})
  set(NX_HOST $ENV{NX_HOST})
else()
  set(NX_HOST "i686-nanos")
endif()

set(CMAKE_SYSTEM_NAME nanos)
set(CMAKE_C_COMPILER   ${NX_HOST}-gcc)
set(CMAKE_CXX_COMPILER ${NX_HOST}-g++)
set(CMAKE_AR           ${NX_HOST}-ar)
set(CMAKE_RANLIB       ${NX_HOST}-ranlib)

if(NX_HOST STREQUAL "x86_64-nanos")
  set(CMAKE_SYSTEM_PROCESSOR x86_64)
  # NanOS x86_64 user ABI: non-PIC, small code model, no red zone (the ring-3 ABI the in-tree
  # crt0/nx.ld expect). -include nx-dllimport.h routes picolibc DATA exports (stderr/errno/...)
  # referenced RIP-relative (R_X86_64_PC32) through the libc.ndl IAT, so a downstream app's mknx
  # can bind them — without it linking the static lib fails on undefined data symbols.
  set(CMAKE_C_FLAGS_INIT   "-fno-pie -mcmodel=small -mno-red-zone -include nx-dllimport.h")
  set(CMAKE_CXX_FLAGS_INIT "-fno-pie -mcmodel=small -mno-red-zone -include nx-dllimport.h")
  set(CMAKE_EXE_LINKER_FLAGS_INIT "-no-pie")
else()
  set(CMAKE_SYSTEM_PROCESSOR i686)
endif()

# We can't run target binaries during configure.
set(CMAKE_CROSSCOMPILING TRUE)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
