/// Verifies the D declarations against the C compiler's view (abi/abi_probe.c).
module abi;

import quickjs_ng;

extern (C) nothrow @nogc
{
    long qjsd_abi_value(int id);
    JSValue qjsd_abi_make_int(int v);
    JSValue qjsd_abi_make_float(double d);
    JSValue qjsd_abi_make_undefined();
    JSValue qjsd_abi_make_bool(int b);
    int qjsd_abi_get_tag(JSValue v);
    int qjsd_abi_get_int(JSValue v);
    double qjsd_abi_get_float(JSValue v);
    JSValue qjsd_abi_echo(JSValue v);
}

// Must match the enum order in abi/abi_probe.c.
private enum : int
{
    ID_SIZEOF_JSVALUE, ID_ALIGNOF_JSVALUE, ID_OFFSETOF_TAG,
    ID_SIZEOF_JSVALUEUNION, ID_SIZEOF_CFUNCTIONTYPE,
    ID_SIZEOF_CFUNCTIONLISTENTRY, ID_OFFSETOF_CFLE_U, ID_SIZEOF_CLASSDEF,
    ID_SIZEOF_EXOTIC, ID_SIZEOF_MEMUSAGE, ID_SIZEOF_PROPDESC, ID_SIZEOF_PROPENUM,
    ID_OFFSETOF_PROPENUM_ATOM, ID_SIZEOF_MALLOCFUNCS, ID_SIZEOF_EVALOPTIONS,
    ID_OFFSETOF_EVALOPTIONS_FILENAME, ID_SIZEOF_SABTAB, ID_SIZEOF_SABFUNCS,
    ID_SIZEOF_BOOL, ID_SIZEOF_ENUM, ID_SIZEOF_CLASSID, ID_SIZEOF_ATOM,
    ID_TAG_FIRST, ID_TAG_OBJECT, ID_TAG_FLOAT64, ID_TAG_EXCEPTION, ID_TAG_SHORT_BIG_INT,
    ID_TAG_STRING_ROPE, ID_TAG_MODULE,
    ID_PROP_C_W_E, ID_PROP_THROW, ID_EVAL_ASYNC, ID_DEF_PROP_BOOL, ID_ABORT_ON_LEAKS,
    ID_VER_MAJOR, ID_VER_MINOR, ID_VER_PATCH, ID_EVAL_OPTIONS_VERSION,
}

unittest // struct layout
{
    assert(qjsd_abi_value(ID_SIZEOF_JSVALUE) == JSValue.sizeof);
    assert(qjsd_abi_value(ID_ALIGNOF_JSVALUE) == JSValue.alignof);
    assert(qjsd_abi_value(ID_OFFSETOF_TAG) == JSValue.tag.offsetof);
    assert(qjsd_abi_value(ID_SIZEOF_JSVALUEUNION) == JSValueUnion.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_CFUNCTIONTYPE) == JSCFunctionType.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_CFUNCTIONLISTENTRY) == JSCFunctionListEntry.sizeof);
    assert(qjsd_abi_value(ID_OFFSETOF_CFLE_U) == JSCFunctionListEntry.u.offsetof);
    assert(qjsd_abi_value(ID_SIZEOF_CLASSDEF) == JSClassDef.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_EXOTIC) == JSClassExoticMethods.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_MEMUSAGE) == JSMemoryUsage.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_PROPDESC) == JSPropertyDescriptor.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_PROPENUM) == JSPropertyEnum.sizeof);
    assert(qjsd_abi_value(ID_OFFSETOF_PROPENUM_ATOM) == JSPropertyEnum.atom.offsetof);
    assert(qjsd_abi_value(ID_SIZEOF_MALLOCFUNCS) == JSMallocFunctions.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_EVALOPTIONS) == JSEvalOptions.sizeof);
    assert(qjsd_abi_value(ID_OFFSETOF_EVALOPTIONS_FILENAME) == JSEvalOptions.filename.offsetof);
    assert(qjsd_abi_value(ID_SIZEOF_SABTAB) == JSSABTab.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_SABFUNCS) == JSSharedArrayBufferFunctions.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_BOOL) == bool.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_ENUM) == JSCFunctionEnum.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_CLASSID) == JSClassID.sizeof);
    assert(qjsd_abi_value(ID_SIZEOF_ATOM) == JSAtom.sizeof);
}

unittest // constants
{
    assert(qjsd_abi_value(ID_TAG_FIRST) == JS_TAG_FIRST);
    assert(qjsd_abi_value(ID_TAG_OBJECT) == JS_TAG_OBJECT);
    assert(qjsd_abi_value(ID_TAG_FLOAT64) == JS_TAG_FLOAT64);
    assert(qjsd_abi_value(ID_TAG_EXCEPTION) == JS_TAG_EXCEPTION);
    assert(qjsd_abi_value(ID_TAG_SHORT_BIG_INT) == JS_TAG_SHORT_BIG_INT);
    assert(qjsd_abi_value(ID_TAG_STRING_ROPE) == JS_TAG_STRING_ROPE);
    assert(qjsd_abi_value(ID_TAG_MODULE) == JS_TAG_MODULE);
    assert(qjsd_abi_value(ID_PROP_C_W_E) == JS_PROP_C_W_E);
    assert(qjsd_abi_value(ID_PROP_THROW) == JS_PROP_THROW);
    assert(qjsd_abi_value(ID_EVAL_ASYNC) == JS_EVAL_FLAG_ASYNC);
    assert(qjsd_abi_value(ID_DEF_PROP_BOOL) == JS_DEF_PROP_BOOL);
    assert(qjsd_abi_value(ID_ABORT_ON_LEAKS) == JS_ABORT_ON_LEAKS);
    assert(qjsd_abi_value(ID_VER_MAJOR) == QJS_VERSION_MAJOR);
    assert(qjsd_abi_value(ID_VER_MINOR) == QJS_VERSION_MINOR);
    assert(qjsd_abi_value(ID_VER_PATCH) == QJS_VERSION_PATCH);
    assert(qjsd_abi_value(ID_EVAL_OPTIONS_VERSION) == JS_EVAL_OPTIONS_VERSION);
}

unittest // by-value JSValue passing and returning agrees with C macros
{
    JSValue a = qjsd_abi_make_int(-42);
    assert(a == JS_NewInt32(null, -42));
    assert(qjsd_abi_get_tag(a) == JS_TAG_INT && qjsd_abi_get_int(a) == -42);

    JSValue f = qjsd_abi_make_float(3.5);
    assert(f == JS_NewFloat64(null, 3.5));
    assert(qjsd_abi_get_tag(f) == JS_TAG_FLOAT64 && qjsd_abi_get_float(f) == 3.5);

    assert(qjsd_abi_make_undefined() == JS_UNDEFINED);
    assert(qjsd_abi_make_bool(1) == JS_TRUE && qjsd_abi_make_bool(0) == JS_FALSE);

    // D-made value passed into C, echoed back, and tag read by C
    JSValue d = JS_NewInt32(null, int.min);
    assert(qjsd_abi_echo(d) == d);
    assert(qjsd_abi_get_int(d) == int.min);
    assert(qjsd_abi_get_tag(JS_NULL) == JS_TAG_NULL);
}

unittest // library version matches the bound headers
{
    import core.stdc.string : strlen;
    import std.conv : to;
    const v = JS_GetVersion();
    assert(v[0 .. strlen(v)] == QJS_VERSION_MAJOR.to!string ~ "." ~ QJS_VERSION_MINOR.to!string
        ~ "." ~ QJS_VERSION_PATCH.to!string ~ QJS_VERSION_SUFFIX);
}
