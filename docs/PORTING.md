# Porting an app to NanOS

1. Make a fork repo for the app (e.g. `vim-nanos`) with the upstream sources (or fetch them via
   the manifest's `source`).
2. Add `nxport.toml`:
   ```toml
   name = "vim"
   source = "git:https://github.com/vim/vim @ v9.1.0000"
   build = "autotools"            # | cmake | meson | make
   configure = ["--without-x", "--disable-gui"]
   cache = ["ac_cv_func_select=yes"]   # extra autoconf cross answers
   needs = ["libc.ndl"]
   binary = "src/vim"             # path to the linked ELF (default: <name>)
   data = ["runtime/ -> /apps/vim/runtime"]
   install = "/apps/vim"
   ```
   Optional `hooks/pre_configure.sh`, `hooks/post_build.sh`.
3. Build: `nanos-port .` inside the `nanos-sdk` container (toolchain on PATH, sysroot synced from a
   built NanOS via `sync-sysroot --nanos=/path`). Produces `<name>.nxe` + `<name>.install`.
4. In NanOS: `make port APP=vim` copies `<name>.nxe` into `bin/`; `make image` installs it as the
   `/apps/<name>` bundle with a `/bin/<name>.nxe` symlink.

The toolchain is a real cross target: `i686-nanos-gcc -dumpmachine` -> `i686-nanos`, `__nanos__`
is defined, and `./configure --host=i686-nanos` is accepted out of the box.
