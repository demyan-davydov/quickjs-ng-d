/// User-defined JavaScript classes backed by D class instances.
///
/// Ownership: the JS object owns the D object. While the JS object is alive the D object is
/// registered as a GC root; when QuickJS finalizes the JS object the root is removed and the
/// D GC may reclaim the instance. D instances must not hold `Value`/`Context` of the same
/// context (cycle invisible to QuickJS) - use the `Context` argument of callbacks instead.
module quickjs_ng.jsclass;

import quickjs_ng.c_api;
import quickjs_ng.context;
import quickjs_ng.exception;
import quickjs_ng.value;
import core.memory : GC;
import std.string : toStringz;

alias CtorFn(T) = T delegate(Context ctx, Value[] args);
alias MethodFn(T) = Value delegate(Context ctx, T self, Value[] args);
alias GetterFn(T) = Value delegate(Context ctx, T self);
alias SetterFn(T) = void delegate(Context ctx, T self, Value value);

private final class Holder(T)
{
    JSClassID id;
    CtorFn!T ctor;
    MethodFn!T method;
    GetterFn!T getter;
    SetterFn!T setter;
}

/// Handle for a registered class. Valid for the runtime it was registered in.
struct JSClass(T)
{
    JSClassID id;
    Value constructor;
    Value prototype;

    /// Creates a JS object that owns `obj`.
    Value wrap(Context ctx, T obj)
    {
        auto proto = JS_GetClassProto(ctx.handle, id);
        auto o = JS_NewObjectProtoClass(ctx.handle, proto, id);
        JS_FreeValue(ctx.handle, proto);
        auto v = ctx.checked(o);
        attach(v.raw, obj);
        return v;
    }

    /// Returns the D object or null if `v` is not an instance of this class.
    T tryUnwrap(Value v) nothrow
    {
        return cast(T) JS_GetOpaque(v.raw, id);
    }

    /// Returns the D object or throws a JS-style TypeError.
    T unwrap(Value v)
    {
        auto t = tryUnwrap(v);
        if (t is null)
            throw new JSException("object is not an instance of the expected class", "TypeError");
        return t;
    }
}

private void attach(T)(JSValue jsobj, T obj) nothrow
{
    GC.addRoot(cast(void*) obj);
    JS_SetOpaque(jsobj, cast(void*) obj);
}

private extern (C) nothrow
{
    void classFinalizer(JSRuntime* rt, JSValue val)
    {
        JSClassID cid;
        void* p = JS_GetAnyOpaque(val, &cid);
        if (p !is null)
            GC.removeRoot(p);
    }

    void holderFinalizer(void* opaque)
    {
        GC.removeRoot(opaque);
    }

    JSValue ctorTramp(T)(JSContext* raw, JSValue newTarget, int argc, JSValue* argv, int magic, void* opaque)
    {
        auto h = cast(Holder!T) opaque;
        return guarded(raw, (Context ctx) {
            if (!JS_IsFunction(raw, newTarget))
                throw new JSException("class constructor cannot be invoked without 'new'", "TypeError");
            if (h.ctor is null)
                throw new JSException("this class cannot be constructed from JS", "TypeError");
            T obj = h.ctor(ctx, makeArgs(ctx, argc, argv));
            JSValue proto = JS_GetPropertyStr(raw, newTarget, "prototype");
            if (!JS_IsObject(proto))
            {
                JS_FreeValue(raw, proto);
                proto = JS_GetClassProto(raw, h.id);
            }
            JSValue o = JS_NewObjectProtoClass(raw, proto, h.id);
            JS_FreeValue(raw, proto);
            auto v = ctx.checked(o);
            attach(v.raw, obj);
            return v;
        });
    }

    JSValue methodTramp(T)(JSContext* raw, JSValue thisVal, int argc, JSValue* argv, int magic, void* opaque)
    {
        auto h = cast(Holder!T) opaque;
        void* p = JS_GetOpaque2(raw, thisVal, h.id); // throws TypeError itself on mismatch
        if (p is null)
            return JS_EXCEPTION;
        return guarded(raw, (Context ctx) => h.method(ctx, cast(T) p, makeArgs(ctx, argc, argv)));
    }

    JSValue getterTramp(T)(JSContext* raw, JSValue thisVal, int argc, JSValue* argv, int magic, void* opaque)
    {
        auto h = cast(Holder!T) opaque;
        void* p = JS_GetOpaque2(raw, thisVal, h.id);
        if (p is null)
            return JS_EXCEPTION;
        return guarded(raw, (Context ctx) => h.getter(ctx, cast(T) p));
    }

    JSValue setterTramp(T)(JSContext* raw, JSValue thisVal, int argc, JSValue* argv, int magic, void* opaque)
    {
        auto h = cast(Holder!T) opaque;
        void* p = JS_GetOpaque2(raw, thisVal, h.id);
        if (p is null)
            return JS_EXCEPTION;
        return guarded(raw, (Context ctx) {
            h.setter(ctx, cast(T) p, argc > 0 ? Value.borrow(ctx, argv[0]) : ctx.undefined());
            return Value.init;
        });
    }
}

/// Fluent builder: `ctx.defineClass!Point("Point", ctor).method(...).property(...).build("Point")`.
final class ClassBuilder(T) if (is(T == class))
{
    private Context ctx;
    private string name;
    private JSClassID id;
    private Value proto;
    private CtorFn!T ctorFn;

    this(Context c, string className, CtorFn!T ctor)
    {
        ctx = c;
        name = className;
        ctorFn = ctor;
        JS_NewClassID(ctx.runtime.handle, &id);
        auto cname = name.toStringz;
        JSClassDef def;
        def.class_name = cname;
        def.finalizer = &classFinalizer;
        if (JS_NewClass(ctx.runtime.handle, id, &def) < 0)
            throw ctx.takeException();
        proto = ctx.newObject();
        // the context keeps its own reference to the prototype
        JS_SetClassProto(ctx.handle, id, JS_DupValue(ctx.handle, proto.raw));
    }

    private Value closure(string n, int nargs, Holder!T h, JSCClosure fn)
    {
        GC.addRoot(cast(void*) h);
        auto f = JS_NewCClosure(ctx.handle, fn, n.toStringz, &holderFinalizer, nargs, 0, cast(void*) h);
        if (JS_IsException(f))
        {
            GC.removeRoot(cast(void*) h);
            throw ctx.takeException();
        }
        return Value.adopt(ctx, f);
    }

    ClassBuilder method(string n, int nargs, MethodFn!T fn)
    {
        auto h = new Holder!T;
        h.id = id;
        h.method = fn;
        proto[n] = closure(n, nargs, h, &methodTramp!T);
        return this;
    }

    /// Accessor property; pass `null` as setter for read-only.
    ClassBuilder property(string n, GetterFn!T getter, SetterFn!T setter = null)
    {
        auto gh = new Holder!T;
        gh.id = id;
        gh.getter = getter;
        auto g = closure(n, 0, gh, &getterTramp!T);
        Value s;
        if (setter !is null)
        {
            auto sh = new Holder!T;
            sh.id = id;
            sh.setter = setter;
            s = closure(n, 1, sh, &setterTramp!T);
        }
        else
            s = ctx.undefined();
        const atom = JS_NewAtom(ctx.handle, n.toStringz);
        scope (exit) JS_FreeAtom(ctx.handle, atom);
        // getter/setter are consumed by the call
        if (JS_DefinePropertyGetSet(ctx.handle, proto.raw, atom, g.take(), s.take(),
                JS_PROP_CONFIGURABLE | JS_PROP_ENUMERABLE) < 0)
            throw ctx.takeException();
        return this;
    }

    /// Creates the constructor function; optionally defines it as a global.
    JSClass!T build(string globalName = null)
    {
        auto h = new Holder!T;
        h.id = id;
        h.ctor = ctorFn;
        auto ctor = closure(name, 0, h, &ctorTramp!T);
        JS_SetConstructorBit(ctx.handle, ctor.raw, true);
        if (JS_SetConstructor(ctx.handle, ctor.raw, proto.raw) < 0)
            throw ctx.takeException();
        if (globalName.length)
            ctx.globalObject()[globalName] = ctor;
        return JSClass!T(id, ctor, proto);
    }
}

ClassBuilder!T defineClass(T)(Context ctx, string name, CtorFn!T ctor = null)
{
    return new ClassBuilder!T(ctx, name, ctor);
}
