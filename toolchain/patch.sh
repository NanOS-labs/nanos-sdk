#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# patch.sh — teach an extracted binutils + gcc source tree the nanos OS target
# (both i686-nanos and x86_64-nanos: a pure mirror of the stock i386/x86-64 ELF rules).
# Usage: patch.sh <binutils-srcdir> <gcc-srcdir> <sdk-toolchain-dir>
set -e
BU="$1"; GCC="$2"; TC="$3"

echo "== patching config.sub (binutils + gcc): accept the nanos OS =="
for cs in "$BU/config.sub" "$GCC/config.sub"; do
	if ! grep -q 'nanos\*' "$cs"; then
		# 14.2/2.43 layout: "...| zvmoe* | qnx* | emx* | zephyr* \" -> add nanos after qnx.
		sed -i 's@| qnx\* | emx\*@| qnx* | nanos* | emx*@' "$cs"
	fi
done

echo "== patching bfd/ld/gas: i686-nanos reuses i386 ELF =="
# Delimiter @ (the patterns contain '|').
sed -i 's@i\[3-7\]86-\*-elf\* | i\[3-7\]86-\*-rtems\*@i[3-7]86-*-nanos* | i[3-7]86-*-elf* | i[3-7]86-*-rtems*@' "$BU/bfd/config.bfd"
sed -i 's@i\[3-7\]86-\*-elf\* | i\[3-7\]86-\*-rtems\*@i[3-7]86-*-nanos* | i[3-7]86-*-elf* | i[3-7]86-*-rtems*@' "$BU/ld/configure.tgt"
sed -i '/^  i386-\*-elf\*)/i\  i386-*-nanos*)			fmt=elf ;;' "$BU/gas/configure.tgt"

echo "== patching bfd/ld: x86_64-nanos reuses x86-64 ELF =="
# Inject x86_64-*-nanos* before the stock x86_64-*-elf* entry (guarded: idempotent).
grep -q 'x86_64-\*-nanos\*' "$BU/bfd/config.bfd"   || sed -i 's@x86_64-\*-elf\* @x86_64-*-nanos* | x86_64-*-elf* @' "$BU/bfd/config.bfd"
grep -q 'x86_64-\*-nanos\*' "$BU/ld/configure.tgt" || sed -i 's@x86_64-\*-elf\* @x86_64-*-nanos* | x86_64-*-elf* @' "$BU/ld/configure.tgt"
# gas needs NO x86_64 rule: gas maps x86_64* -> cpu_type=i386 (configure.tgt), so generic_target
# becomes i386-*-nanos* and the i386-*-nanos rule above already selects fmt=elf for x86_64-nanos.

echo "== patching gcc/config.gcc + installing i386/nanos.h =="
if ! grep -q 'i\[34567\]86-\*-nanos\*' "$GCC/gcc/config.gcc"; then
	awk '
	  /^i\[34567\]86-\*-elf\*\)$/ {
	    print "i[34567]86-*-nanos*)";
	    print "\ttm_file=\"${tm_file} i386/unix.h i386/att.h elfos.h newlib-stdint.h i386/i386elf.h i386/nanos.h\"";
	    print "\t;;";
	  }
	  {print}
	' "$GCC/gcc/config.gcc" > "$GCC/gcc/config.gcc.new"
	mv "$GCC/gcc/config.gcc.new" "$GCC/gcc/config.gcc"
fi
# x86_64-nanos: mirror the stock x86_64-*-elf* tm_file (which layers i386/x86-64.h for the LP64
# 64-bit ABI + SSE2 baseline), then append i386/nanos.h for the NanOS spec overrides.
if ! grep -q 'x86_64-\*-nanos\*' "$GCC/gcc/config.gcc"; then
	awk '
	  /^x86_64-\*-elf\*\)$/ {
	    print "x86_64-*-nanos*)";
	    print "\ttm_file=\"${tm_file} i386/unix.h i386/att.h elfos.h newlib-stdint.h i386/i386elf.h i386/x86-64.h i386/nanos.h\"";
	    print "\t;;";
	  }
	  {print}
	' "$GCC/gcc/config.gcc" > "$GCC/gcc/config.gcc.new"
	mv "$GCC/gcc/config.gcc.new" "$GCC/gcc/config.gcc"
fi
# Single arch-neutral nanos.h serves both i686 and x86_64 (the 64-bit ABI comes from x86-64.h above).
cp "$TC/nanos.h" "$GCC/gcc/config/i386/nanos.h"

# libgcc has its own host table; teach it i686-nanos (mirror i386-*-elf*).
if ! grep -q 'i\[34567\]86-\*-nanos\*' "$GCC/libgcc/config.host"; then
	awk '
	  /^i\[34567\]86-\*-elf\*\)$/ {
	    print "i[34567]86-*-nanos*)";
	    print "\ttmake_file=\"$tmake_file i386/t-crtstuff t-crtstuff-pic t-libgcc-pic\"";
	    print "\t;;";
	  }
	  {print}
	' "$GCC/libgcc/config.host" > "$GCC/libgcc/config.host.new"
	mv "$GCC/libgcc/config.host.new" "$GCC/libgcc/config.host"
fi

# libgcc: mirror the stock "x86_64-*-elf* | x86_64-*-rtems*)" host rule for x86_64-nanos.
if ! grep -q 'x86_64-\*-nanos\*' "$GCC/libgcc/config.host"; then
	awk '
	  /^x86_64-\*-elf\* \| x86_64-\*-rtems\*\)$/ {
	    print "x86_64-*-nanos*)";
	    print "\ttmake_file=\"$tmake_file i386/t-crtstuff t-crtstuff-pic t-libgcc-pic\"";
	    print "\t;;";
	  }
	  {print}
	' "$GCC/libgcc/config.host" > "$GCC/libgcc/config.host.new"
	mv "$GCC/libgcc/config.host.new" "$GCC/libgcc/config.host"
fi

echo "== verify =="
grep -q 'nanos\*' "$BU/config.sub"            && echo "  binutils config.sub: OK"
grep -q 'nanos\*' "$GCC/config.sub"           && echo "  gcc config.sub: OK"
grep -q 'i\[3-7\]86-\*-nanos\*' "$BU/bfd/config.bfd"    && echo "  bfd/config.bfd: OK"
grep -q 'i\[3-7\]86-\*-nanos\*' "$BU/ld/configure.tgt"  && echo "  ld/configure.tgt: OK"
grep -q 'i386-\*-nanos\*' "$BU/gas/configure.tgt"       && echo "  gas/configure.tgt: OK"
grep -q 'i\[34567\]86-\*-nanos\*' "$GCC/gcc/config.gcc" && echo "  gcc/config.gcc: OK"
test -f "$GCC/gcc/config/i386/nanos.h"        && echo "  gcc/config/i386/nanos.h: installed"
grep -q 'i\[34567\]86-\*-nanos\*' "$GCC/libgcc/config.host" && echo "  libgcc/config.host: OK"
grep -q 'x86_64-\*-nanos\*' "$BU/bfd/config.bfd"    && echo "  bfd x86_64: OK"
grep -q 'x86_64-\*-nanos\*' "$BU/ld/configure.tgt"  && echo "  ld  x86_64: OK"
grep -q 'i386-\*-nanos\*'   "$BU/gas/configure.tgt" && echo "  gas x86_64: OK (via i386 cpu_type)"
grep -q 'x86_64-\*-nanos\*' "$GCC/gcc/config.gcc"   && echo "  gcc/config.gcc x86_64: OK"
grep -q 'x86_64-\*-nanos\*' "$GCC/libgcc/config.host" && echo "  libgcc x86_64: OK"
