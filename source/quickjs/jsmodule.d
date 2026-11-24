/// ES module support: source loader, native (D-implemented) modules, module evaluation.
module quickjs.jsmodule;

import quickjs.c_api;
import quickjs.context;
import quickjs.exception;
import quickjs.runtime;
import quickjs.value;
import core.memory : GC;
import std.string : toStringz;

/// Returns the source of module `name` (already normalized), or null if it does not exist.
alias ModuleLoader = string delegate(string name);

private final class LoaderHolder
{
    ModuleLoader load;
}

private extern (C) nothrow
{
    void loaderFinalizer(JSRuntime* rt, void* arg)
    {
        GC.removeRoot(arg);
    }

    JSModuleDef* loaderTramp(JSContext* raw, const(char)* moduleName, void* opaque)
    {
        import core.stdc.string : strlen;
        auto h = cast(LoaderHolder) opaque;
        string name = moduleName[0 .. strlen(moduleName)].idup;
        try
        {
            string src = h.load(name);
            if (src is null)
            {
                JS_ThrowReferenceError(raw, "could not load module '%s'", moduleName);
                return null;
            }
            auto buf = src ~ '\0';
            JSValue f = JS_Eval(raw, buf.ptr, src.length, moduleName,
                JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
            if (JS_IsException(f))
                return null;
            auto m = cast(JSModuleDef*) JS_VALUE_GET_PTR(f);
            JS_FreeValue(raw, f); // the module stays registered in the context
            return m;
        }
        catch (Throwable e)
        {
            try { throwJS(raw, "", e.msg); } catch (Throwable) {}
            return null;
        }
    }

    int nativeModuleInit(JSContext* raw, JSModuleDef* m)
    {
        JSValue priv = JS_GetModulePrivateValue(raw, m);
        scope (exit) JS_FreeValue(raw, priv);
        JSValue arg = JS_NewInt64(raw, cast(long) m); // user-space pointers fit in 2^53
        JSValue r = JS_Call(raw, priv, JS_UNDEFINED, 1, &arg);
        if (JS_IsException(r))
            return -1;
        JS_FreeValue(raw, r);
        return 0;
    }
}

/// Installs a loader that supplies module sources from D. Replaces a previous loader.
/// Imports are normalized by QuickJS' default resolver (relative names are resolved
/// against the importer).
void setModuleLoader(ref Runtime rt, ModuleLoader loader)
{
    auto h = new LoaderHolder;
    h.load = loader;
    GC.addRoot(cast(void*) h);
    JS_AddRuntimeFinalizer(rt.handle, &loaderFinalizer, cast(void*) h);
    JS_SetModuleLoaderFunc(rt.handle, null, &loaderTramp, cast(void*) h);
}

/// Exports of a native module, valid only inside its init delegate.
struct NativeExports
{
    private Context ctx;
    private JSModuleDef* m;

    @property Context context() { return ctx; }

    void set(T)(string name, auto ref T value)
    {
        auto v = ctx.make(value);
        if (JS_SetModuleExport(ctx.handle, m, name.toStringz, v.take()) < 0)
            throw ctx.takeException();
    }
}

alias NativeModuleInit = void delegate(ref NativeExports exports);

/// Registers a module implemented in D. `exportNames` must list every export that `init`
/// sets; `init` runs lazily when the module is first instantiated by an import.
/// Note: a module is registered per context.
void defineNativeModule(Context ctx, string name, string[] exportNames, NativeModuleInit init)
{
    auto m = JS_NewCModule(ctx.handle, name.toStringz, &nativeModuleInit);
    if (m is null)
        throw ctx.takeException();
    foreach (e; exportNames)
        if (JS_AddModuleExport(ctx.handle, m, e.toStringz) < 0)
            throw ctx.takeException();
    // The init delegate lives in a closure stored as the module's private value, so its
    // lifetime is that of the module (no global registry, no manual cleanup).
    auto f = ctx.newFunction("init", 1, (Context c, Value self, Value[] a) {
        NativeExports ex;
        ex.ctx = c;
        ex.m = cast(JSModuleDef*) a[0].to!long;
        init(ex);
        return Value.init;
    });
    JS_SetModulePrivateValue(ctx.handle, m, f.take());
}

/// Runs pending jobs and unwraps a promise: returns its value or throws `JSException`
/// if it was rejected. Non-promises are returned unchanged.
Value settle(Context ctx, Value p)
{
    auto rt = ctx.runtime;
    rt.executePendingJobs();
    if (!p.isPromise)
        return p;
    final switch (p.promiseState)
    {
        case JSPromiseStateEnum.JS_PROMISE_FULFILLED:
            return p.promiseResult;
        case JSPromiseStateEnum.JS_PROMISE_REJECTED:
            auto r = p.promiseResult;
            JS_PromiseMarkAsHandled(ctx.handle, p.raw);
            throw exceptionFromValue(ctx.handle, r.raw);
        case JSPromiseStateEnum.JS_PROMISE_PENDING:
            throw new JSException("promise is still pending (unresolved top-level await?)");
        case JSPromiseStateEnum.JS_PROMISE_NOT_A_PROMISE:
            return p;
    }
}

/// Evaluates module source and waits for its completion; throws if it failed.
Value runModule(Context ctx, string code, string name = "<module>")
{
    return settle(ctx, ctx.evalModule(code, name));
}

/// Imports module `name` (via the loader or a native module) and returns its namespace object.
Value importModule(Context ctx, string name)
{
    auto p = ctx.checked(JS_LoadModule(ctx.handle, "", name.toStringz, JS_UNDEFINED));
    return settle(ctx, p);
}
