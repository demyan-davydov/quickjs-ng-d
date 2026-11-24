# quickjs_ng

D binding for [QuickJS-NG](https://github.com/quickjs-ng/quickjs), a small embeddable JavaScript engine.
The engine's C sources are bundled and compiled on your machine; nothing is downloaded at build time.

- **Bundled engine:** QuickJS-NG **v0.18.0** (commit `d7215b0`), see [VENDOR.md](VENDOR.md)
- **Package version:** independent semver. The tag carries the engine version as build metadata,
  e.g. `v0.1.0+quickjs-0.18.0`. Updating the bundled engine bumps the minor version while we are `0.x`.
- **License:** MIT (same as QuickJS-NG), see [LICENSE](LICENSE)

## Status

| Component | Status |
|---|---|
| Low-level C API binding (`quickjs_ng.c_api`) | done |
| High-level API: `Runtime`, `Context`, `Value`, `JSException` | done |
| Classes (`defineClass`), modules (loader, native modules) | done |
| Static linking (`static` configuration, default) | done |
| `dynamic`, `system` configurations | not implemented |
| Verified in CI (ldc2, `dub test`): Linux x86_64, Linux ARM64, macOS ARM64, macOS x86_64, Windows x86_64 (MSVC) | yes |
| 32-bit targets | not supported |

## Use

```sdl
dependency "quickjs_ng" path="path/to/quickjs-ng-d"   // or version="~>0.1.0" once published
```

```d
import quickjs_ng;

void main()
{
    auto ctx = Runtime.create().createContext();
    assert(ctx.eval("1 + 2").to!int == 3);
}
```

The D sources are compiled together with your project (`sourceLibrary`); only the C engine is built
separately into `build/lib/libquickjs-ng.a` by `scripts/build.sh` on every DUB invocation (incremental).
Consequence: DUB refuses `dub build` inside this package itself; use `dub test` and `examples/`.

Requirements: DUB, a D compiler (ldc2 tested), a C compiler (`cc`). No CMake.
Ownership and threading rules: [OWNERSHIP.md](OWNERSHIP.md). Tests: `dub test --compiler=ldc2`.
