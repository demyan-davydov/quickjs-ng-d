# Ownership rules (high-level API)

| Type | Owns | Copy | Destroy |
|---|---|---|---|
| `Runtime` | counted `JSRuntime` | refcount++ | refcount--, `JS_FreeRuntime` at 0 |
| `Context` | `JS_DupContext` reference + a `Runtime` copy | `JS_DupContext` | `JS_FreeContext` |
| `Value` | one `JS_DupValue` reference + a `Context` copy | `JS_DupValue` | `JS_FreeValue` |

Consequences
- Destruction order cannot be wrong: a `Value` keeps its `Context`, a `Context` keeps its `Runtime`.
  "Context destroyed before its Values" is impossible; the context just lives until the last Value dies.
- `Value.adopt(ctx, raw)` takes an owned raw JSValue; `Value.borrow` dups a borrowed one;
  `value.take()` gives the owned reference back to C and empties the Value.
- `Value.raw` / `Context.handle` / `Runtime.handle` are borrowed: do not free them, do not
  keep them past the owning D object.
- JS exceptions become `JSException` (plain strings, no JS handles). Errors never escape
  through C frames: native callbacks catch every D `Throwable` and convert it into a JS exception.
- Cycles QuickJS cannot see leak: do not capture a `Context`/`Value` of context X in a delegate
  registered as a function in X. Use the `Context` argument passed to the delegate instead.
- Threads: QuickJS is not thread-safe. Refcounts here are non-atomic: use a runtime and everything
  derived from it from one thread at a time.
- Do not store `Value`/`Context` in GC-managed class fields unless you destroy them explicitly:
  GC finalizer timing/thread is unspecified. Prefer stack/struct ownership or `destroy()`.
- Leak check: `runtime.setDumpFlags(JS_DUMP_LEAKS)` makes `JS_FreeRuntime` report (and abort on) leaks; used in tests.

## Classes (`quickjs.jsclass`)
- `ctx.defineClass!T(name, ctor).method(...).property(...).build("Global")` registers a JS class
  backed by a D `class T`. The class id lives in the runtime; the prototype is kept by the context.
- The JS object owns its D instance: the instance is a GC root while the JS object lives, and the
  root is removed by the QuickJS finalizer. Use `JSClass!T.wrap/unwrap/tryUnwrap` to cross the boundary.
- D instances must not store `Value`/`Context` of the same context (invisible cycle => leak).
- Calling a class without `new`, or a method on a foreign receiver, throws a JS `TypeError`.

## Modules (`quickjs.jsmodule`)
- `rt.setModuleLoader(name => source)` supplies ES module source from D (return `null` => `ReferenceError`);
  QuickJS caches modules per context, so the loader runs once per module name.
- `ctx.defineNativeModule(name, exports, init)` registers a module implemented in D; `init` runs lazily
  on first import. Its delegate lives in a closure stored as the module's private value (freed with the module).
- `ctx.runModule(code)` / `ctx.importModule(name)` run pending jobs and unwrap the completion promise:
  a rejection becomes a `JSException`; a still-pending promise (unresolved top-level await) is an error.
