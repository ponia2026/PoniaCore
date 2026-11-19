# Licensing notes

This repository contains only build recipes, scripts and CI configuration.
Each core is built from its upstream source and remains under the upstream
license. A core's `recipe.env` records:

- `LICENSE`: SPDX identifier of the upstream license
- `COMMERCIAL_OK`: `yes` or `no` (whether the core may be bundled into
  installation packages that are distributed commercially)

Cores with `COMMERCIAL_OK=no` are only downloaded by the user on first use and
are never included in an installation package.

Status of the planned cores (to be verified against upstream before the first
release):

| Core             | Upstream license | Commercial OK |
| ---------------- | ---------------- | ------------- |
| mupen64plus_next | GPL-2.0          | to verify     |
| yabasanshiro     | GPL-2.0          | to verify     |
| ppsspp           | GPL-2.0          | to verify     |
| dolphin          | GPL-2.0          | to verify     |
| fake08           | MIT              | to verify     |
