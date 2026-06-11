# CMake cross file for NanOS. Use: cmake -DCMAKE_TOOLCHAIN_FILE=.../toolchain-nanos.cmake
set(CMAKE_SYSTEM_NAME nanos)
set(CMAKE_SYSTEM_PROCESSOR i686)
set(CMAKE_C_COMPILER   i686-nanos-gcc)
set(CMAKE_CXX_COMPILER i686-nanos-g++)
set(CMAKE_AR           i686-nanos-ar)
set(CMAKE_RANLIB       i686-nanos-ranlib)
# We can't run target binaries during configure.
set(CMAKE_CROSSCOMPILING TRUE)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
