/// High-level `Value`.
///
/// Ownership: a `Value` OWNS one reference to its JSValue (if it has a reference count).
///  * copying a `Value` calls JS_DupValue; destroying it calls JS_FreeValue;
///  * it keeps its `Context` alive, so it can never outlive it;
///  * `adopt` takes over an already-owned raw JSValue, `borrow` dups a borrowed one;
///  * `take()` hands the owned reference back to C (e.g. a native callback's return value)
///    and leaves the Value empty.
/// A default-constructed `Value` is empty (`isValid == false`).
/// Do not store Values in GC-managed class fields without destroying them explicitly:
/// the D GC does not guarantee when (or on which thread) finalizers run, and QuickJS is
/// single-threaded.
module quickjs_ng.value;

import quickjs_ng.c_api;
import quickjs_ng.context;
import quickjs_ng.exception;
import std.traits : isIntegral, isFloatingPoint, isSomeString;

struct Value
{
    private Context ctx;
    private JSValue v;

    /// Takes ownership of `raw` (no dup).
    static Value adopt(ref Context ctx, JSValue raw)
    {
        Value r;
        r.ctx = ctx;
        r.v = raw;
        return r;
    }

    /// Dups `raw` (borrowed by the caller).
    static Value borrow(ref Context ctx, JSValue raw) nothrow
    {
        Value r;
        r.ctx = ctx;
        r.v = JS_DupValue(ctx.handle, raw);
        return r;
    }

    this(ref return scope Value rhs) nothrow
    {
        ctx = rhs.ctx;
        v = rhs.ctx.handle ? JS_DupValue(rhs.ctx.handle, rhs.v) : rhs.v;
    }

    ~this() nothrow
    {
        if (ctx.handle !is null)
            JS_FreeValue(ctx.handle, v);
        // `ctx` (and through it the runtime) is released after this body runs.
    }

    @property bool isValid() nothrow { return ctx.handle !is null; }

    /// Raw JSValue, still owned by this Value (borrow only).
    @property JSValue raw() nothrow { return v; }

    /// Releases ownership of the reference to the caller; this Value becomes empty.
    JSValue take() nothrow
    {
        auto r = v;
        v = JSValue.init;
        ctx = Context.init; // drops the context reference WITHOUT freeing the value
        return r;
    }

    @property Context context() { return ctx; }

    // ---- type predicates ----
    @property bool isUndefined() nothrow { return JS_IsUndefined(v); }
    @property bool isNull() nothrow { return JS_IsNull(v); }
    @property bool isBool() nothrow { return JS_IsBool(v); }
    @property bool isNumber() nothrow { return JS_IsNumber(v); }
    @property bool isBigInt() nothrow { return JS_IsBigInt(v); }
    @property bool isString() nothrow { return JS_IsString(v); }
    @property bool isSymbol() nothrow { return JS_IsSymbol(v); }
    @property bool isObject() nothrow { return JS_IsObject(v); }
    @property bool isArray() nothrow { return JS_IsArray(v); }
    @property bool isError() nothrow { return JS_IsError(v); }
    @property bool isFunction() nothrow { return JS_IsFunction(ctx.handle, v); }
    @property bool isPromise() nothrow { return JS_IsPromise(v); }

    // ---- conversions ----

    /// Converts to a D type using JS semantics. Throws `JSException` if the JS conversion throws.
    T to(T)()
    {
        static if (is(T == bool))
        {
            const r = JS_ToBool(ctx.handle, v);
            if (r < 0) throw ctx.takeException();
            return r != 0;
        }
        else static if (isIntegral!T)
        {
            long x;
            if (JS_ToInt64Ext(ctx.handle, &x, v) < 0) throw ctx.takeException();
            return cast(T) x;
        }
        else static if (isFloatingPoint!T)
        {
            double d;
            if (JS_ToFloat64(ctx.handle, &d, v) < 0) throw ctx.takeException();
            return cast(T) d;
        }
        else static if (isSomeString!T)
        {
            import std.conv : to;
            size_t len;
            const(char)* s = JS_ToCStringLen(ctx.handle, &len, v);
            if (s is null) throw ctx.takeException();
            scope (exit) JS_FreeCString(ctx.handle, s);
            return s[0 .. len].idup.to!T;
        }
        else
            static assert(false, "quickjs: cannot convert JS value to " ~ T.stringof);
    }

    string toString() { return to!string; }

    // ---- properties ----

    Value opIndex(string name)
    {
        import std.string : toStringz;
        return ctx.checked(JS_GetPropertyStr(ctx.handle, v, name.toStringz));
    }

    Value opIndex(size_t i)
    {
        return ctx.checked(JS_GetPropertyUint32(ctx.handle, v, cast(uint) i));
    }

    void opIndexAssign(T)(auto ref T value, string name)
    {
        import std.string : toStringz;
        auto x = ctx.make(value);
        if (JS_SetPropertyStr(ctx.handle, v, name.toStringz, x.take()) < 0)
            throw ctx.takeException();
    }

    void opIndexAssign(T)(auto ref T value, size_t i)
    {
        auto x = ctx.make(value);
        if (JS_SetPropertyUint32(ctx.handle, v, cast(uint) i, x.take()) < 0)
            throw ctx.takeException();
    }

    /// `length` of an array-like object.
    long length()
    {
        long n;
        if (JS_GetLength(ctx.handle, v, &n) < 0) throw ctx.takeException();
        return n;
    }

    // ---- promises ----
    JSPromiseStateEnum promiseState() nothrow { return JS_PromiseState(ctx.handle, v); }
    Value promiseResult() { return Value.adopt(ctx, JS_PromiseResult(ctx.handle, v)); }

    // ---- calls ----

    /// Calls this function with `this = undefined`.
    Value call(Args...)(auto ref Args args)
    {
        return callWithThis(JS_UNDEFINED, args);
    }

    /// Calls the method `name` of this object.
    Value callMethod(Args...)(string name, auto ref Args args)
    {
        auto f = this[name];
        return f.callWithThis(v, args);
    }

    private Value callWithThis(Args...)(JSValue thisRaw, auto ref Args args)
    {
        Value[Args.length] conv;
        JSValue[Args.length] rawArgs;
        static foreach (i, A; Args)
        {
            conv[i] = ctx.make(args[i]);
            rawArgs[i] = conv[i].raw;
        }
        return ctx.checked(JS_Call(ctx.handle, v, thisRaw, cast(int) Args.length,
            Args.length ? rawArgs.ptr : null));
    }
}
