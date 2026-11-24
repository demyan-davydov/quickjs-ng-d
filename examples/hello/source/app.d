import quickjs_ng;
import std.stdio;

void main()
{
    auto runtime = Runtime.create();
    auto context = runtime.createContext();

    context.setGlobalFunction("greet", 1, (Context c, Value self, Value[] a) =>
        c.make("Привет, " ~ a[0].to!string ~ "!"));

    writeln(context.eval("1 + 2").to!int);
    writeln(context.eval(`greet("мир")`).to!string);

    try
        context.eval(`null.x`);
    catch (JSException e)
        writeln(e.jsName, ": ", e.msg);
}
