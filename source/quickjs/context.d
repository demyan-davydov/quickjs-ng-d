/// High-level `Context`.
///
/// Ownership: `Context` is a counted handle (JS_DupContext / JS_FreeContext) and also holds
/// a `Runtime` copy. `Value`s hold a `Context` copy, so contexts outlive their values and
/// runtimes outlive their contexts - destruction order can never be wrong.
module quickjs.context;

import quickjs.c_api;
import quickjs.exception;
import quickjs.runtime;
import quickjs.value;
import std.traits : isIntegral, isFloatingPoint, isSomeString, isArray;
import std.string : toStringz;

/// Signature of D functions callable from JavaScript.
alias NativeFunction = Value delegate(Context ctx, Value thisVal, Value[] args);

struct Context
{
    private JSContext* c;
    private Runtime rt;

    package this(ref Runtime runtime)
    {
        c = JS_NewContext(runtime.handle);
        if (c is null)
            throw new JSException("JS_NewContext failed");
        rt = runtime;
    }

    /// Wraps a raw context (counted: dups it). For native callbacks.
    package static Context fromRaw(JSContext* raw) nothrow @nogc
    {
        Context x;
        x.c = JS_DupContext(raw);
        x.rt = Runtime.fromRaw(JS_GetRuntime(raw));
        return x;
    }

    this(ref return scope Context rhs) nothrow @nogc
    {
        c = rhs.c ? JS_DupContext(rhs.c) : null;
        rt = rhs.rt;
    }

    ~this() nothrow @nogc
    {
        if (c !is null)
            JS_FreeContext(c);
        c = null;
    }

    bool opCast(T : bool)() const nothrow @nogc { return c !is null; }

    /// Raw handle (borrowed).
    @property JSContext* handle() nothrow @nogc { return c; }
    @property Runtime runtime() { return rt; }

    // ---- evaluation ----

    /// Evaluates a script. Throws `JSException` on a JS exception.
    Value eval(string code, string filename = "<eval>", int flags = JS_EVAL_TYPE_GLOBAL)
    {
        auto buf = code ~ '\0'; // JS_Eval needs a NUL-terminated buffer
        return checked(JS_Eval(c, buf.ptr, code.length, filename.toStringz, flags));
    }

    /// Evaluates ES module code (returns the module's completion promise/value).
    Value evalModule(string code, string filename = "<module>")
    {
        return eval(code, filename, JS_EVAL_TYPE_MODULE);
    }

    Value parseJSON(string json, string filename = "<json>")
    {
        auto buf = json ~ '\0';
        return checked(JS_ParseJSON(c, buf.ptr, json.length, filename.toStringz));
    }

    // ---- value construction ----

    Value globalObject() { return Value.adopt(this, JS_GetGlobalObject(c)); }
    Value newObject() { return checked(JS_NewObject(c)); }
    Value newArray() { return checked(JS_NewArray(c)); }
    Value undefined() { return Value.adopt(this, JS_UNDEFINED); }
    Value null_() { return Value.adopt(this, JS_NULL); }

    /// Converts a D value: bool, integers, floating point, strings, `Value`, arrays of those,
    /// `typeof(null)`. Throws `JSException` on failure.
    Value make(T)(auto ref T x)
    {
        static if (is(T == Value))
            return x; // copy => dup
        else static if (is(T == typeof(null)))
            return null_();
        else static if (is(T == bool))
            return Value.adopt(this, JS_NewBool(c, x));
        else static if (isIntegral!T)
        {
            static if (T.sizeof <= 4 && __traits(isUnsigned, T) == false)
                return Value.adopt(this, JS_NewInt32(c, x));
            else static if (__traits(isUnsigned, T))
                return Value.adopt(this, JS_NewUint64(c, x));
            else
                return Value.adopt(this, JS_NewInt64(c, x));
        }
        else static if (isFloatingPoint!T)
            return Value.adopt(this, JS_NewFloat64(c, x));
        else static if (isSomeString!T)
        {
            import std.conv : to;
            string s = x.to!string;
            return checked(JS_NewStringLen(c, s.ptr, s.length));
        }
        else static if (isArray!T)
        {
            auto arr = newArray();
            foreach (i, ref e; x)
            {
                auto v = make(e);
                if (JS_SetPropertyUint32(c, arr.raw, cast(uint) i, v.take()) < 0)
                    throw takeException();
            }
            return arr;
        }
        else
            static assert(false, "quickjs: cannot convert " ~ T.stringof ~ " to a JS value");
    }

    /// Creates a JS function backed by a D delegate.
    /// D exceptions thrown by `fn` become JS exceptions (`JSException` keeps its error class;
    /// others become plain Errors). Do not let the delegate capture a `Context`/`Value`
    /// of this same context: that creates a reference cycle QuickJS cannot see (leak).
    Value newFunction(string name, int nargs, NativeFunction fn)
    {
        import core.memory : GC;
        auto h = new Holder(fn);
        GC.addRoot(cast(void*) h); // keep delegate context alive while JS owns the closure
        auto f = JS_NewCClosure(c, &closureTrampoline, name.toStringz, &closureFinalizer,
            nargs, 0, cast(void*) h);
        if (JS_IsException(f))
        {
            GC.removeRoot(cast(void*) h);
            throw takeException();
        }
        return Value.adopt(this, f);
    }

    /// Defines a global function.
    void setGlobalFunction(string name, int nargs, NativeFunction fn)
    {
        auto g = globalObject();
        g[name] = newFunction(name, nargs, fn);
    }

    // ---- exceptions ----

    /// Removes the pending JS exception from the context and returns it as a D exception.
    JSException takeException() { return makeException(c); }

    /// Takes ownership of `v`; throws if it is `JS_EXCEPTION`.
    package Value checked(JSValue v)
    {
        if (JS_IsException(v))
            throw takeException();
        return Value.adopt(this, v);
    }
}

// ---- native function plumbing ----

private final class Holder
{
    NativeFunction fn;
    this(NativeFunction f) { fn = f; }
}

package extern (C) nothrow:

JSValue closureTrampoline(JSContext* raw, JSValue thisVal, int argc, JSValue* argv, int magic, void* opaque)
{
    auto h = cast(Holder) opaque;
    try
    {
        auto ctx = Context.fromRaw(raw);
        auto self = Value.borrow(ctx, thisVal);
        auto args = new Value[argc];
        foreach (i; 0 .. argc)
            args[i] = Value.borrow(ctx, argv[i]);
        Value r = h.fn(ctx, self, args);
        if (!r.isValid)
            return JS_UNDEFINED;
        return r.take();
    }
    catch (JSException e)
    {
        return throwJS(raw, e.jsName, e.msg);
    }
    catch (Throwable e)
    {
        try { return throwJS(raw, "", e.msg); } catch (Throwable) { return JS_EXCEPTION; }
    }
}

void closureFinalizer(void* opaque)
{
    import core.memory : GC;
    GC.removeRoot(opaque);
}

JSValue throwJS(JSContext* raw, string name, string msg)
{
    auto m = toStringz(msg);
    switch (name)
    {
        case "TypeError": return JS_ThrowTypeError(raw, "%s", m);
        case "RangeError": return JS_ThrowRangeError(raw, "%s", m);
        case "SyntaxError": return JS_ThrowSyntaxError(raw, "%s", m);
        case "ReferenceError": return JS_ThrowReferenceError(raw, "%s", m);
        default: return JS_ThrowPlainError(raw, "%s", m);
    }
}

// ---- exception extraction (raw level) ----
package extern (D):

/// Converts a JS value to a D string without throwing; clears any exception it causes.
string rawToString(JSContext* c, JSValue v) nothrow
{
    size_t len;
    const(char)* s = JS_ToCStringLen(c, &len, v);
    if (s is null)
    {
        JS_FreeValue(c, JS_GetException(c));
        return "";
    }
    string r = s[0 .. len].idup;
    JS_FreeCString(c, s);
    return r;
}

string rawPropString(JSContext* c, JSValue obj, const(char)* prop) nothrow
{
    JSValue v = JS_GetPropertyStr(c, obj, prop);
    scope (exit) JS_FreeValue(c, v);
    if (JS_IsException(v))
    {
        JS_FreeValue(c, JS_GetException(c));
        return "";
    }
    return JS_IsUndefined(v) ? "" : rawToString(c, v);
}

/// Pops the pending exception of `c` and converts it.
JSException makeException(JSContext* c) nothrow
{
    JSValue ex = JS_GetException(c);
    scope (exit) JS_FreeValue(c, ex);
    return exceptionFromValue(c, ex);
}

/// Converts a (borrowed) thrown JS value into a D exception.
JSException exceptionFromValue(JSContext* c, JSValue ex) nothrow
{
    string name, msg, stack;
    if (JS_IsError(ex))
    {
        name = rawPropString(c, ex, "name");
        msg = rawPropString(c, ex, "message");
        stack = rawPropString(c, ex, "stack");
    }
    else
        msg = rawToString(c, ex);
    try
        return new JSException(msg, name, stack);
    catch (Throwable)
        assert(0, "out of memory creating JSException");
}

/// Runs `body` with a counted Context for native callbacks; converts every D Throwable into a
/// pending JS exception. Returns the owned JSValue result (JS_UNDEFINED for an empty Value).
JSValue guarded(JSContext* raw, scope Value delegate(Context ctx) body) nothrow
{
    try
    {
        auto ctx = Context.fromRaw(raw);
        Value r = body(ctx);
        return r.isValid ? r.take() : JS_UNDEFINED;
    }
    catch (JSException e)
        return throwJS(raw, e.jsName, e.msg);
    catch (Throwable e)
    {
        try { return throwJS(raw, "", e.msg); } catch (Throwable) { return JS_EXCEPTION; }
    }
}

Value[] makeArgs(ref Context ctx, int argc, JSValue* argv)
{
    auto args = new Value[argc];
    foreach (i; 0 .. argc)
        args[i] = Value.borrow(ctx, argv[i]);
    return args;
}
