# Vendored upstream

- Project: QuickJS-NG, https://github.com/quickjs-ng/quickjs
- Tag: v0.18.0
- Commit: d7215b0ad3fc2c562e8317fd9bca058fd4863804
- Location: `vendor/quickjs-ng/` (tests, docs, examples and test262 removed; `.git` removed)
- Compiled sources: `quickjs.c libregexp.c libunicode.c dtoa.c` (the upstream `qjs_sources`
  without `quickjs-libc.c`) plus `abi/abi_probe.c`.
- Defines/flags (from upstream CMake): `-std=gnu11 -funsigned-char -DQUICKJS_NG_BUILD -D_GNU_SOURCE`.
- To update: replace the directory, bump `quickjs_ng.constants` version constants, re-diff
  `quickjs.h` against `source/quickjs_ng/{types,constants,c_api}.d`, run `dub test`.
