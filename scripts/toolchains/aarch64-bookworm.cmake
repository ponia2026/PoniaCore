# CMake toolchain: x86_64 host -> aarch64 target, using a Debian 12 (bookworm) sysroot.
# Usage: cmake -S <src> -B <build> -DCMAKE_TOOLCHAIN_FILE=<this file> [-DPONIA_SYSROOT=/path]

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(PONIA_SYSROOT "/chroot/bookworm-arm64" CACHE PATH "aarch64 Debian 12 sysroot")
set(CMAKE_SYSROOT "${PONIA_SYSROOT}")

set(CMAKE_C_COMPILER   aarch64-linux-gnu-gcc-12)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++-12)

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
    "${PONIA_SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig:${PONIA_SYSROOT}/usr/share/pkgconfig:${PONIA_SYSROOT}/usr/lib/pkgconfig")

# The host cross compiler inserts its own newer glibc headers ahead of the sysroot, which makes the
# code reference symbols such as __isoc23_strtol that the sysroot's glibc does not have. -isystem
# puts the sysroot headers first.
set(PONIA_SYSROOT_INCLUDES
    "-isystem ${PONIA_SYSROOT}/usr/include/aarch64-linux-gnu -isystem ${PONIA_SYSROOT}/usr/include")
set(CMAKE_C_FLAGS_INIT   "${PONIA_SYSROOT_INCLUDES}")
# The sysroot and the target boards ship gcc 12 libstdc++. Building with the gcc 13 cross compiler
# emits symbols (e.g. std::string::_M_replace_cold) that libstdc++ 12 does not export, and
# mixing gcc 12 headers into gcc 13 fails to compile. Use the gcc 12 cross compiler (apt: g++-12-aarch64-linux-gnu).
set(CMAKE_CXX_FLAGS_INIT "${PONIA_SYSROOT_INCLUDES}")

# Use the sysroot's gcc 12 libstdc++ (dynamic), not the host's gcc 13 one. The sysroot's libm.so is
# a symlink with an absolute target that dangles on the host, so a shim directory (made by the build
# script, passed as PONIA_LIB_SHIM) is searched first to find the shared libm instead of libm.a.
set(PONIA_LIB_SHIM "" CACHE PATH "directory holding a libm.so symlink to the sysroot's libm.so.6")
set(_PONIA_LD "-L${PONIA_LIB_SHIM} -L${PONIA_SYSROOT}/usr/lib/gcc/aarch64-linux-gnu/12")
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${_PONIA_LD}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT
    "${_PONIA_LD} -Wl,-rpath-link,${PONIA_SYSROOT}/usr/lib/aarch64-linux-gnu:${PONIA_SYSROOT}/lib/aarch64-linux-gnu")
