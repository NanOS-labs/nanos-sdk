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

## License

This SDK is **GPL-3.0-or-later**. It produces and patches GNU toolchain software:

- `toolchain/nanos.h` is a GCC target-config header (compiled into GCC) and the `toolchain/`
  patches modify GCC and binutils — all GPLv3.
- `port/config.sub`, `port/config.guess` are upstream GNU files (GPLv3 with the autoconf output
  exception); they keep their own headers.
- The built cross toolchain is GNU **binutils + GCC** (GPLv3), downloaded from ftp.gnu.org by
  `build-toolchain.sh` — this repo ships patches, not the GNU sources or binaries.
- **picolibc** (built by the Dockerfile) is under its own BSD/MIT-style licenses; it is not
  redistributed in this repo.
- The driver and helper scripts (`nanos-port`, `sync-sysroot`, cross files) are GPLv3 too.

Application **ports are separate fork repos** (e.g. `vim-nanos`, `ncurses-nanos`) and keep their
upstream licenses (Vim license, ncurses/X11 license); this SDK only builds them.
