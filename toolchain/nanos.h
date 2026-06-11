/* SPDX-License-Identifier: GPL-3.0-or-later */
/* i386/nanos.h — NanOS (i686-nanos) target overrides, layered on top of i386elf.h.
 *
 * Makes a stock i386 ELF GCC produce NanOS programs: define the __nanos__ system macros, start
 * at crt0.o + the .nxe header object (no crtbegin/crtend), link with the NanOS linker script and
 * keep relocations so mknx can build the .nxe relocation table, and pull the C library from
 * libc.ndl's import library (installed as libc.a in the sysroot). Static model; the .ndl
 * "shared" objects are produced by mknx, not by the linker. */

#undef TARGET_OS_CPP_BUILTINS
#define TARGET_OS_CPP_BUILTINS()		\
  do {						\
      builtin_define ("__nanos__");		\
      builtin_define ("__NanOS__");		\
      builtin_assert ("system=nanos");		\
  } while (0)

/* Startup: crt0 (_start -> main -> exit) + the .nxe header placeholder object. */
#undef STARTFILE_SPEC
#define STARTFILE_SPEC "crt0.o%s nxhdr.o%s"

#undef ENDFILE_SPEC
#define ENDFILE_SPEC ""

/* Link at the NanOS base via nx.ld (overridable with -T) and keep R_386_32 relocations for mknx.
 * --unresolved-symbols=ignore-all lets direct references to libc.ndl DATA (stdout/errno/_ctype_b/
 * environ) stay undefined here; mknx turns them into auto-imports (Windows/MinGW-style) that the
 * loader patches with the real address, so stock code links without the dllimport shim. Missing
 * FUNCTIONS are R_386_PC32 and mknx warns on those, so genuine link gaps still surface. */
#undef LINK_SPEC
#define LINK_SPEC "%{!T:-T nx.ld} --emit-relocs -z noexecstack --unresolved-symbols=ignore-all"

/* libc.ndl import library, installed as libc.a; libgcc is added by the driver as usual. */
#undef LIB_SPEC
#define LIB_SPEC "-lc"
