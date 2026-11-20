# CMake toolchain: x86_64 host -> 32-bit ARM (armhf) target, using a Debian 12 (bookworm) sysroot.
# Usage: cmake -S <src> -B <build> -DCMAKE_TOOLCHAIN_FILE=<this file> [-DPONIA_SYSROOT=/path]

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(PONIA_SYSROOT "/chroot/bookworm-armhf" CACHE PATH "armhf Debian 12 sysroot")
set(CMAKE_SYSROOT "${PONIA_SYSROOT}")

set(CMAKE_C_COMPILER   arm-linux-gnueabihf-gcc-12)
set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++-12)

# Libraries and headers come only from the sysroot; build-time programs come from the host.
set(CMAKE_FIND_ROOT_PATH "${PONIA_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# pkg-config must read the sysroot's .pc files, not the host's.
set(ENV{PKG_CONFIG_DIR} "")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${PONIA_SYSROOT}")
set(ENV{PKG_CONFIG_LIBDIR}
    "${PONIA_SYSROOT}/usr/lib/arm-linux-gnueabihf/pkgconfig:${PONIA_SYSROOT}/usr/share/pkgconfig:${PONIA_SYSROOT}/usr/lib/pkgconfig")

# The host cross compiler inserts its own newer glibc headers ahead of the sysroot, which makes the
# code reference symbols such as __isoc23_strtol that the sysroot's glibc does not have. -isystem
# puts the sysroot headers first.
set(PONIA_SYSROOT_INCLUDES
    "-isystem ${PONIA_SYSROOT}/usr/include/arm-linux-gnueabihf -isystem ${PONIA_SYSROOT}/usr/include")
set(CMAKE_C_FLAGS_INIT   "${PONIA_SYSROOT_INCLUDES} -march=armv7-a -mfpu=neon -mfloat-abi=hard")
# The sysroot and the target boards ship gcc 12 libstdc++. Building with the gcc 13 cross compiler
# emits symbols (e.g. std::string::_M_replace_cold) that libstdc++ 12 does not export, and
# mixing gcc 12 headers into gcc 13 fails to compile. Use the gcc 12 cross compiler (apt: g++-12-arm-linux-gnueabihf).
set(CMAKE_CXX_FLAGS_INIT "${PONIA_SYSROOT_INCLUDES} -march=armv7-a -mfpu=neon -mfloat-abi=hard")

# Use the sysroot's gcc 12 libstdc++ (dynamic), not the host's gcc 13 one. The sysroot's libm.so is
# a symlink with an absolute target that dangles on the host, so a shim directory (made by the build
# script, passed as PONIA_LIB_SHIM) is searched first to find the shared libm instead of libm.a.
set(PONIA_LIB_SHIM "" CACHE PATH "directory holding a libm.so symlink to the sysroot's libm.so.6")
set(_PONIA_LD "-L${PONIA_LIB_SHIM} -L${PONIA_SYSROOT}/usr/lib/gcc/arm-linux-gnueabihf/12")
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${_PONIA_LD}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT
    "${_PONIA_LD} -Wl,-rpath-link,${PONIA_SYSROOT}/usr/lib/arm-linux-gnueabihf:${PONIA_SYSROOT}/lib/arm-linux-gnueabihf")
