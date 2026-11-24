/// High-level `Runtime`.
///
/// Ownership: `Runtime` is a reference-counted handle. Copying it increments a counter;
/// the underlying `JSRuntime` is freed when the last copy is destroyed. Every `Context`
/// keeps a `Runtime` copy, so a runtime always outlives its contexts.
/// QuickJS is not thread-safe: use a runtime (and everything created from it) from one
/// thread at a time.
module quickjs_ng.runtime;

import quickjs_ng.c_api;
import quickjs_ng.context;
import quickjs_ng.exception;
import core.stdc.stdlib : malloc, free;

struct Runtime
{
    private static struct Payload
    {
        JSRuntime* rt;
        size_t refs;
    }

    private Payload* p;

    /// Creates a new runtime. Throws on out-of-memory.
    static Runtime create()
    {
        auto rt = JS_NewRuntime();
        if (rt is null)
            throw new JSException("JS_NewRuntime failed");
        auto pl = cast(Payload*) malloc(Payload.sizeof);
        if (pl is null)
        {
            JS_FreeRuntime(rt);
            throw new JSException("out of memory");
        }
        pl.rt = rt;
        pl.refs = 1;
        JS_SetRuntimeOpaque(rt, pl); // lets native callbacks recover a Runtime handle
        Runtime r;
        r.p = pl;
        return r;
    }

    /// Recovers a (counted) handle from a raw `JSRuntime*` created by `create`.
    package static Runtime fromRaw(JSRuntime* rt) nothrow @nogc
    {
        Runtime r;
        r.p = cast(Payload*) JS_GetRuntimeOpaque(rt);
        if (r.p) ++r.p.refs;
        return r;
    }

    this(ref return scope Runtime rhs) nothrow @nogc
    {
        p = rhs.p;
        if (p) ++p.refs;
    }

    ~this() nothrow @nogc
    {
        if (p !is null && --p.refs == 0)
        {
            JS_FreeRuntime(p.rt);
            free(p);
        }
        p = null;
    }

    bool opCast(T : bool)() const nothrow @nogc { return p !is null; }

    /// Raw handle (borrowed; valid while any copy of this Runtime lives).
    @property JSRuntime* handle() nothrow @nogc { return p ? p.rt : null; }

    Context createContext() { return Context(this); }

    void setMemoryLimit(size_t bytes) { JS_SetMemoryLimit(handle, bytes); }
    void setMaxStackSize(size_t bytes) { JS_SetMaxStackSize(handle, bytes); }
    void setGCThreshold(size_t bytes) { JS_SetGCThreshold(handle, bytes); }
    void runGC() { JS_RunGC(handle); }
    /// Enables QuickJS leak reports printed by JS_FreeRuntime (testing aid).
    void setDumpFlags(ulong flags) { JS_SetDumpFlags(handle, flags); }

    bool isJobPending() { return JS_IsJobPending(handle); }

    /// Runs all pending promise jobs. Returns the number executed;
    /// throws `JSException` if a job threw.
    int executePendingJobs()
    {
        int n;
        for (;;)
        {
            JSContext* c;
            const r = JS_ExecutePendingJob(handle, &c);
            if (r == 0)
                return n;
            if (r < 0)
                throw makeException(c);
            ++n;
        }
    }
}
