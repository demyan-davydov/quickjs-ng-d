/// Smoke tests that really run JavaScript through the low-level binding.
module smoke;

import quickjs_ng;
import core.stdc.string : strlen;

private JSValue evalStr(JSContext* ctx, string src)
{
    // JS_Eval requires a zero-terminated buffer
    return JS_Eval(ctx, (src ~ '\0').ptr, src.length, "<eval>", JS_EVAL_TYPE_GLOBAL);
}

unittest // eval("1 + 2")
{
    JSRuntime* rt = JS_NewRuntime();
    assert(rt !is null);
    JSContext* ctx = JS_NewContext(rt);
    assert(ctx !is null);

    JSValue r = evalStr(ctx, "1 + 2");
    assert(!JS_IsException(r));
    assert(JS_IsNumber(r));
    int i;
    assert(JS_ToInt32(ctx, &i, r) == 0);
    assert(i == 3);
    JS_FreeValue(ctx, r);

    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

unittest // strings, unicode, exceptions, properties, native callback, leak check
{
    JSRuntime* rt = JS_NewRuntime();
    JS_SetDumpFlags(rt, JS_DUMP_LEAKS); // report leaks on JS_FreeRuntime
    JSContext* ctx = JS_NewContext(rt);

    // unicode round trip
    JSValue s = evalStr(ctx, `"привет, " + "мир é"`);
    assert(JS_IsString(s));
    size_t len;
    const(char)* cs = JS_ToCStringLen(ctx, &len, s);
    assert(cs !is null);
    assert(cs[0 .. len] == "привет, мир é");
    JS_FreeCString(ctx, cs);
    JS_FreeValue(ctx, s);

    // exception
    JSValue bad = evalStr(ctx, `throw new TypeError("boom")`);
    assert(JS_IsException(bad));
    JSValue exc = JS_GetException(ctx);
    assert(JS_IsError(exc));
    JSValue msg = JS_GetPropertyStr(ctx, exc, "message");
    const(char)* m = JS_ToCString(ctx, msg);
    assert(m[0 .. strlen(m)] == "boom");
    JS_FreeCString(ctx, m);
    JS_FreeValue(ctx, msg);
    JS_FreeValue(ctx, exc);

    // object property set/get (SetPropertyStr takes ownership of the value)
    JSValue obj = JS_NewObject(ctx);
    assert(JS_SetPropertyStr(ctx, obj, "x", JS_NewInt32(ctx, 7)) >= 0);
    JSValue x = JS_GetPropertyStr(ctx, obj, "x");
    int xi;
    JS_ToInt32(ctx, &xi, x);
    assert(xi == 7);
    JS_FreeValue(ctx, x);

    // native function called from JS
    static extern (C) JSValue twice(JSContext* c, JSValue thisVal, int argc, JSValue* argv) nothrow
    {
        int v;
        if (argc < 1 || JS_ToInt32(c, &v, argv[0]) < 0)
            return JS_EXCEPTION;
        return JS_NewInt32(c, v * 2);
    }
    JSValue global = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global, "twice", JS_NewCFunction(ctx, &twice, "twice", 1));
    JS_FreeValue(ctx, global);
    JSValue t = evalStr(ctx, "twice(21)");
    int ti;
    JS_ToInt32(ctx, &ti, t);
    assert(ti == 42);
    JS_FreeValue(ctx, t);

    JS_FreeValue(ctx, obj);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt); // aborts via JS_DUMP_LEAKS output if anything leaked
}

unittest // repeated create/destroy
{
    foreach (_; 0 .. 50)
    {
        JSRuntime* rt = JS_NewRuntime();
        JSContext* ctx = JS_NewContext(rt);
        JSValue r = evalStr(ctx, "[1,2,3].map(x => x * x).join(',')");
        assert(JS_IsString(r));
        JS_FreeValue(ctx, r);
        JS_RunGC(rt);
        JS_FreeContext(ctx);
        JS_FreeRuntime(rt);
    }
}
