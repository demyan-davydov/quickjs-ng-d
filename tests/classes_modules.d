module classes_modules;

import quickjs_ng;
import std.exception : collectException;

class Point
{
    double x, y;
    this(double x, double y) { this.x = x; this.y = y; }
    double norm2() { return x * x + y * y; }
}

private JSClass!Point definePoint(Context ctx)
{
    return ctx.defineClass!Point("Point", (Context c, Value[] a) =>
            new Point(a.length > 0 ? a[0].to!double : 0, a.length > 1 ? a[1].to!double : 0))
        .method("norm2", 0, (Context c, Point p, Value[] a) => c.make(p.norm2()))
        .method("add", 1, (Context c, Point p, Value[] a) { p.x += a[0].to!double; return Value.init; })
        .property("x", (Context c, Point p) => c.make(p.x), (Context c, Point p, Value v) { p.x = v.to!double; })
        .property("y", (Context c, Point p) => c.make(p.y))   // read-only
        .build("Point");
}

unittest // class: construct, methods, accessors
{
    auto rt = Runtime.create();
    rt.setDumpFlags(JS_DUMP_LEAKS);
    auto ctx = rt.createContext();
    definePoint(ctx);
    assert(ctx.eval("new Point(3, 4).norm2()").to!int == 25);
    assert(ctx.eval("var p = new Point(1, 2); p.add(2); p.x").to!int == 3);
    assert(ctx.eval("p.x = 10; p.x").to!int == 10);
    assert(ctx.eval("p instanceof Point && Point.name == 'Point' && p.constructor === Point").to!bool);
    // wrong receiver -> TypeError, class not constructible without new
    auto e = collectException!JSException(ctx.eval("Point.prototype.norm2.call({})"));
    assert(e && e.jsName == "TypeError");
    e = collectException!JSException(ctx.eval("Point(1,2)"));
    assert(e && e.jsName == "TypeError");
    // JS subclassing
    assert(ctx.eval("class P3 extends Point { z() { return 7; } }; var q = new P3(0, 5); q.z() + q.y").to!int == 12);
}

unittest // wrap/unwrap D objects, GC finalization
{
    auto rt = Runtime.create();
    rt.setDumpFlags(JS_DUMP_LEAKS);
    auto ctx = rt.createContext();
    auto cls = definePoint(ctx);
    auto d = new Point(6, 8);
    auto v = cls.wrap(ctx, d);
    assert(cls.unwrap(v) is d);
    ctx.globalObject()["wrapped"] = v;
    assert(ctx.eval("wrapped.norm2()").to!int == 100);
    assert(cls.tryUnwrap(ctx.newObject()) is null);
    assert(collectException!JSException(cls.unwrap(ctx.newObject())) !is null);
    foreach (i; 0 .. 100)
        cls.wrap(ctx, new Point(i, i)); // dropped immediately -> finalizer runs
    ctx.eval("var junk = []; for (let i = 0; i < 100; i++) junk.push(new Point(i, i)); junk = null;");
    rt.runGC();
}

unittest // exceptions thrown from D methods
{
    auto ctx = Runtime.create().createContext();
    class Boom { }
    ctx.defineClass!Boom("Boom", (Context c, Value[] a) => new Boom)
        .method("go", 0, (Context c, Boom b, Value[] a) { throw new JSException("bad", "RangeError"); return Value.init; })
        .build("Boom");
    assert(ctx.eval(`try { new Boom().go() } catch (e) { e.name + ":" + e.message }`).to!string == "RangeError:bad");
}

unittest // modules from a D loader, with relative imports and caching
{
    auto rt = Runtime.create();
    rt.setDumpFlags(JS_DUMP_LEAKS);
    int loads;
    string[string] files = [
        "lib/math.js": `import { base } from "./base.js"; export const six = base * 2; export function sq(x) { return x * x; }`,
        "lib/base.js": `export const base = 3;`,
    ];
    rt.setModuleLoader((string name) { ++loads; return name in files ? files[name] : null; });
    auto ctx = rt.createContext();

    ctx.runModule(`import { six, sq } from "lib/math.js"; globalThis.r = sq(six);`, "main.js");
    assert(ctx.globalObject()["r"].to!int == 36);
    assert(loads == 2);

    auto ns = ctx.importModule("lib/base.js");
    assert(ns["base"].to!int == 3);
    assert(loads == 2); // already loaded

    auto e = collectException!JSException(ctx.runModule(`import "nope.js";`, "m2.js"));
    assert(e !is null && e.jsName == "ReferenceError");
    e = collectException!JSException(ctx.runModule(`throw new TypeError("top")`, "m3.js"));
    assert(e !is null && e.jsName == "TypeError" && e.msg == "top");
}

unittest // native modules
{
    auto rt = Runtime.create();
    rt.setDumpFlags(JS_DUMP_LEAKS);
    auto ctx = rt.createContext();
    int inits;
    ctx.defineNativeModule("native", ["answer", "greet", "add"], (ref NativeExports ex) {
        ++inits;
        ex.set("answer", 42);
        ex.set("greet", "привет");
        ex.set("add", ex.context.newFunction("add", 2, (Context c, Value s, Value[] a) => c.make(a[0].to!int + a[1].to!int)));
    });
    assert(inits == 0); // lazy
    ctx.runModule(`import { answer, greet, add } from "native"; globalThis.out = greet + (answer + add(1, 2));`);
    assert(ctx.globalObject()["out"].to!string == "привет45");
    assert(inits == 1);
    ctx.runModule(`import { answer } from "native"; globalThis.again = answer;`, "m2");
    assert(inits == 1);
}
