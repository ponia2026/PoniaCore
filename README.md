# PoniaCore

Prebuilt emulator cores for [PoniaEmu](https://github.com/ponia2026/PoniaEmu).

This repository holds the build recipes and CI workflows for libretro-style
cores that are not available (or not usable) from the official libretro
buildbot on some platforms, for example GLES builds for Mali-class ARM boards.
Built binaries are published as GitHub Releases and downloaded by PoniaEmu's
core installer on demand.

## Layout

```
cores/<core>/recipe.env   upstream URL, pinned commit, license, targets
cores/<core>/build.sh     builds the core for one target (see below)
scripts/                  shared helpers (toolchain setup, packaging)
docs/                     notes on targets, naming and licensing
.github/workflows/        CI: build cores, publish a Release
```

## Targets

| Target id      | Description                                   |
| -------------- | --------------------------------------------- |
| `linux-x86_64` | Debian 12 baseline (glibc 2.36)               |
| `linux-arm64`  | Debian 12 sysroot, GLES (Mali / panfrost)     |
| `linux-armhf`  | Debian 12 sysroot, 32-bit ARM                 |
| `windows-x64`  | Planned                                       |

## Output naming

Release assets follow the libretro convention so the installer can treat them
like official cores:

```
<core>_libretro.so                  (inside <core>_libretro.so.zip per target)
PoniaCore_<core>-<date>.<commit8>_<target>.zip
SHA256SUMS.txt
```

## First planned cores

- `mupen64plus_next` (N64, GLES3 build)
- `yabasanshiro` (Saturn, GLES build)
- `ppsspp` (PSP, GLES build)
- `dolphin` (GameCube/Wii, GLES build, 64-bit ARM only)
- `fake08` (PICO-8, built against the Debian 12 baseline)

## Licensing

Every core keeps its own upstream license; see `recipe.env` in each core
directory and `docs/licensing.md`. Cores with non-commercial or otherwise
restrictive terms are marked there and are never bundled into the PoniaEmu
installation packages.
