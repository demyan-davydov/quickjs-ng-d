module highlevel;

import quickjs;
import std.exception : assertThrown, collectException;

unittest // spec example
{
    auto runtime = Runtime.create();
    auto context = runtime.createContext();
    auto result = context.eval("1 + 2");
    assert(result.to!int == 3);
}

unittest // scalar types, strings, unicode
{
    auto ctx = Runtime.create().createContext(); // runtime temp dies; context keeps it alive
    assert(ctx.eval("true").to!bool);
    assert(ctx.eval("2.5").to!double == 2.5);
    assert(ctx.eval("null").isNull && ctx.eval("undefined").isUndefined);
    auto s = ctx.eval(`"привет " + "мир"`);
    assert(s.isString && s.to!string == "привет мир");
    assert(ctx.make("日本語").to!string == "日本語");
}

unittest // objects, arrays, properties, JSON
{
    auto ctx = Runtime.create().createContext();
    auto o = ctx.newObject();
    o["a"] = 1;
    o["name"] = "x";
    o["list"] = [1, 2, 3];
    assert(o["a"].to!int == 1 && o["name"].to!string == "x");
    assert(o["list"].isArray && o["list"].length == 3 && o["list"][2].to!int == 3);
    auto j = ctx.parseJSON(`{"k":[10,20]}`);
    assert(j["k"][1].to!int == 20);
}

unittest // calling JS from D
{
    auto ctx = Runtime.create().createContext();
    auto f = ctx.eval("(function(a, b) { return a * b; })");
    assert(f.isFunction && f.call(6, 7).to!int == 42);
    auto arr = ctx.eval("[3,1,2]");
    assert(arr.callMethod("join", "-").to!string == "3-1-2");
}

unittest // D functions called from JS, errors both ways
{
    auto ctx = Runtime.create().createContext();
    ctx.setGlobalFunction("add", 2, (Context c, Value self, Value[] a) => c.make(a[0].to!int + a[1].to!int));
    assert(ctx.eval("add(40, 2)").to!int == 42);

    ctx.setGlobalFunction("fail", 0, (Context c, Value self, Value[] a) {
        throw new JSException("nope", "TypeError");
        return Value.init;
    });
    assert(ctx.eval(`try { fail(); "no" } catch (e) { e instanceof TypeError ? e.message : "wrong" }`).to!string == "nope");

    auto e = collectException!JSException(ctx.eval(`null.x`));
    assert(e !is null && e.jsName == "TypeError");
    auto e2 = collectException!JSException(ctx.eval(`throw new RangeError("r")`));
    assert(e2.jsName == "RangeError" && e2.msg == "r" && e2.jsStack.length);
    auto e3 = collectException!JSException(ctx.eval(`throw "plain"`));
    assert(e3.msg == "plain");
    assertThrown!JSException(ctx.eval("(")); // SyntaxError
    assert(ctx.eval("1").to!int == 1);       // context still usable
}

unittest // closures capturing D state
{
    auto ctx = Runtime.create().createContext();
    int counter;
    ctx.setGlobalFunction("tick", 0, (Context c, Value s, Value[] a) { return c.make(++counter); });
    ctx.eval("tick(); tick(); tick();");
    assert(counter == 3);
}

unittest // lifetime: values outlive the context/runtime variables that created them
{
    Value kept;
    {
        auto rt = Runtime.create();
        auto ctx = rt.createContext();
        kept = ctx.eval("({ v: [1,2,3] })");
    } // rt and ctx variables gone; `kept` keeps context+runtime alive
    assert(kept["v"][1].to!int == 2);
}

unittest // copies are independent owners (refcount correctness)
{
    auto rt = Runtime.create();
    rt.setDumpFlags(JS_DUMP_LEAKS);
    {
        auto ctx = rt.createContext();
        auto a = ctx.eval("({x: 1})");
        auto b = a;       // dup
        auto c = b;       // dup
        a = Value.init;   // free one
        assert(b["x"].to!int == 1 && c["x"].to!int == 1);
        auto raw = c.take();           // ownership moved out
        assert(!c.isValid);
        JS_FreeValue(ctx.handle, raw); // we free it ourselves
    }
    // rt dtor runs JS_FreeRuntime with leak reporting: would print leaked objects
}

unittest // GC, promises/jobs, repeated lifecycle
{
    foreach (_; 0 .. 20)
    {
        auto rt = Runtime.create();
        auto ctx = rt.createContext();
        ctx.eval("var r = 0; Promise.resolve(5).then(v => { r = v; });");
        assert(rt.isJobPending);
        assert(rt.executePendingJobs() == 1);
        assert(ctx.globalObject()["r"].to!int == 5);
        ctx.eval("var cyc = {}; cyc.self = cyc; cyc = null;");
        rt.runGC();
    }
}

unittest // memory limit surfaces as exception
{
    auto rt = Runtime.create();
    rt.setMemoryLimit(2 * 1024 * 1024);
    auto ctx = rt.createContext();
    assertThrown!JSException(ctx.eval(`var a = []; for (;;) a.push(new Array(1000).fill(1));`));
}
