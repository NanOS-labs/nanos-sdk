/* SPDX-License-Identifier: GPL-3.0-or-later */
/* i386/nanos.h — NanOS target overrides, layered on top of the base i386 ELF target headers
 * (i386elf.h for i686-nanos; i386elf.h + x86-64.h for x86_64-nanos). Arch-neutral: the 32/64-bit
 * ABI (LP64, SSE2 baseline) comes from those base headers; this file only adds NanOS specifics.
 *
 * Makes a stock i386/x86-64 ELF GCC produce NanOS programs: define the __nanos__ system macros, start
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
      /* Expose the POSIX/GNU surface by default (like a hosted Linux gcc) so picolibc's	\
       * feature-gated declarations — lstat, strdup, etc. — are visible to stock code and	\
       * to configure's function probes, instead of being hidden on a bare-elf target. */	\
      builtin_define ("_DEFAULT_SOURCE");	\
      builtin_define ("_GNU_SOURCE");		\
  } while (0)

/* Startup: crt0 (_start -> main -> exit) + the .nxe header placeholder object. */
#undef STARTFILE_SPEC
#define STARTFILE_SPEC "crt0.o%s nxhdr.o%s"

#undef ENDFILE_SPEC
#define ENDFILE_SPEC ""

/* Link at the NanOS base via nx.ld (overridable with -T) and keep absolute relocations for mknx:
 * R_386_32 on i686, R_X86_64_64 (+ R_X86_64_32S) on x86_64 — consistent with tools/mknx.c and the
 * low-2GiB small-model load base (decision #1). gcc emits them; --emit-relocs preserves them.
 * --unresolved-symbols=ignore-all lets direct references to libc.ndl DATA (stdout/errno/_ctype_b/
 * environ) stay undefined here; mknx turns them into auto-imports (Windows/MinGW-style) that the
 * loader patches with the real address, so stock code links without the dllimport shim. Missing
 * FUNCTIONS are R_386_PC32 and mknx warns on those, so genuine link gaps still surface. */
#undef LINK_SPEC
#define LINK_SPEC "%{!T:-T nx.ld} --emit-relocs -z noexecstack --unresolved-symbols=ignore-all"

/* libc.ndl import library, installed as libc.a; libgcc is added by the driver as usual. */
#undef LIB_SPEC
#define LIB_SPEC "-lc"
