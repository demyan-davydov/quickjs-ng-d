#!/usr/bin/env sh
# Builds the vendored QuickJS-NG (+ ABI probe) into build/lib/libquickjs-ng.a (static)
# or build/lib/libquickjs-ng.{dylib,so} (dynamic: `build.sh dynamic`).
# Honors CC, AR, CFLAGS, LDFLAGS. Rebuilds only if sources, flags or compiler change.
set -eu

MODE="${1:-static}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/vendor/quickjs-ng"
OUT="$ROOT/build/lib"
OBJ="$ROOT/build/obj-$MODE"
CC="${CC:-cc}"
AR="${AR:-ar}"
OS="$(uname -s)"

case "$MODE" in
  static|dynamic) ;;
  *) echo "usage: $0 [static|dynamic]" >&2; exit 2 ;;
esac

# Warnings upstream silences in its own build, plus -funsigned-char which QuickJS relies on.
BASE_CFLAGS="-std=gnu11 -O2 -fPIC -funsigned-char -DQUICKJS_NG_BUILD -D_GNU_SOURCE \
 -Wno-implicit-fallthrough -Wno-sign-compare -Wno-missing-field-initializers \
 -Wno-unused-parameter -Wno-unused-but-set-variable -Wno-unused-result -Wno-array-bounds"
[ "$MODE" = dynamic ] && BASE_CFLAGS="$BASE_CFLAGS -DBUILDING_QJS_SHARED -fvisibility=hidden"
ALL_CFLAGS="$BASE_CFLAGS ${CFLAGS:-}"

case "$MODE" in
  static) TARGET="$OUT/libquickjs-ng.a" ;;
  dynamic) case "$OS" in Darwin) TARGET="$OUT/libquickjs-ng.dylib" ;; *) TARGET="$OUT/libquickjs-ng.so" ;; esac ;;
esac

SOURCES="$SRC/quickjs.c $SRC/libregexp.c $SRC/libunicode.c $SRC/dtoa.c $ROOT/abi/abi_probe.c"
HEADERS="$SRC/*.h"
STAMP="$OBJ/flags.stamp"
mkdir -p "$OUT" "$OBJ"

# Flag/compiler stamp: change => full rebuild.
NEW_STAMP="$("$CC" --version 2>&1 | head -n 1) | $ALL_CFLAGS | ${LDFLAGS:-} | $AR"
if [ ! -f "$STAMP" ] || [ "$(cat "$STAMP")" != "$NEW_STAMP" ]; then
  rm -f "$OBJ"/*.o "$TARGET"
  printf '%s' "$NEW_STAMP" > "$STAMP"
fi

NEED_LINK=0
[ -f "$TARGET" ] || NEED_LINK=1
for s in $SOURCES; do
  o="$OBJ/$(basename "$s" .c).o"
  rebuild=0
  [ -f "$o" ] || rebuild=1
  if [ $rebuild = 0 ]; then
    [ "$s" -nt "$o" ] && rebuild=1
    for h in $HEADERS; do [ "$h" -nt "$o" ] && rebuild=1; done
  fi
  if [ $rebuild = 1 ]; then
    echo "CC  $(basename "$s")"
    # shellcheck disable=SC2086
    "$CC" $ALL_CFLAGS -I"$SRC" -c "$s" -o "$o"
    NEED_LINK=1
  fi
done

if [ $NEED_LINK = 1 ]; then
  rm -f "$TARGET"
  if [ "$MODE" = static ]; then
    echo "AR  $(basename "$TARGET")"
    "$AR" rcs "$TARGET" "$OBJ"/*.o
  else
    echo "LD  $(basename "$TARGET")"
    case "$OS" in
      Darwin) "$CC" -dynamiclib -install_name "@rpath/$(basename "$TARGET")" -o "$TARGET" "$OBJ"/*.o -lm ${LDFLAGS:-} ;;
      *) "$CC" -shared -o "$TARGET" "$OBJ"/*.o -lm -ldl -lpthread ${LDFLAGS:-} ;;
    esac
  fi
fi
