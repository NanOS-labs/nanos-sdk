# nanos-sdk

A native cross-toolchain for **NanOS** with the `i686-nanos` target triplet, plus a universal
port system so a Linux app builds for NanOS from a tiny `nxport.toml` manifest.

- `toolchain/` — patches that teach binutils + gcc the `i686-nanos` OS target.
- `build-toolchain.sh` / `Dockerfile` — build `i686-nanos-{gcc,g++,ld,as,...}` from source.
- `sysroot/` — populate `/opt/i686-nanos` (picolibc + NanOS glue headers, crt0/nxhdr/libc.ndl.a/nx.ld).
- `bin/` — `i686-nanos-mknx` (ELF -> .nxe post-link step).
- `port/` — the `nanos-port` driver, base `config.cache`, CMake/meson cross files.
- `docs/` — how to port an app.

Design spec: NanOS repo `docs/superpowers/specs/2026-06-11-nanos-sdk-cross-toolchain-design.md`.
