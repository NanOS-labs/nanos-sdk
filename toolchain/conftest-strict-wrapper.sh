#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
#
# <triple>-nanos-gcc wrapper — make autoconf's link probes honest.
#
# Triple-agnostic: derives the cross triple from its own install name (<triple>-gcc), so the
# SAME script serves i686-nanos and x86_64-nanos. Installed as <triple>-gcc; the real driver is
# <triple>-gcc.real next to it. (Originally i686-only; generalised for the x86_64 cut-over.)
#
# The NanOS gcc spec links with --unresolved-symbols=ignore-all so stock code can reference
# libc.ndl DATA (stdout/errno/environ) that mknx turns into Windows/MinGW-style auto-imports.
# But that same flag makes autoconf's AC_CHECK_FUNC LINK test succeed for EVERY function —
# even ones NanOS lacks — so gnulib-heavy ports get false HAVE_<fn>=1 and then fail to compile
# (implicit declarations) or call missing symbols.
#
# autoconf names its probe program `conftest`. For those links we override the spec with
# --unresolved-symbols=report-all (ld honours the LAST --unresolved-symbols on the line), so a
# reference to an absent function is a hard error and the function is correctly reported missing.
#
# report-all alone is too strict, though: many probes reference a libc DATA symbol (e.g.
# gnulib's __fpending test does `__fpending(stdin)`), and those data symbols are intentionally
# left undefined at link time for mknx's auto-import. We therefore also add the conftest data
# stub (conftest-data-stubs.o, built by gen-conftest-stubs.sh) which WEAKLY defines exactly the
# pure-data exports. Net effect for a conftest: functions resolve strictly from libc.a, data
# resolves from the weak stub, and genuinely-absent symbols fail — faithful detection, while
# real program links keep ignore-all for the auto-import.
strict=
prev=
for a in "$@"; do
	if [ "$prev" = "-o" ]; then
		case "$a" in
			conftest | conftest.* | */conftest | */conftest.*) strict=1 ;;
		esac
	fi
	prev=$a
done

dir=$(dirname "$0")
self=$(basename "$0")           # <triple>-gcc
triple=${self%-gcc}             # <triple>  (e.g. i686-nanos / x86_64-nanos)
real="$dir/$self.real"

if [ -n "$strict" ]; then
	# Locate the data stub relative to the driver (toolchain/bin -> ../<triple>/lib).
	stub="$dir/../$triple/lib/conftest-data-stubs.o"
	[ -f "$stub" ] || stub=$("$real" -print-sysroot 2>/dev/null)/lib/conftest-data-stubs.o
	if [ -f "$stub" ]; then
		exec "$real" "$@" "$stub" -Wl,--unresolved-symbols=report-all
	fi
	exec "$real" "$@" -Wl,--unresolved-symbols=report-all
fi
exec "$real" "$@"
