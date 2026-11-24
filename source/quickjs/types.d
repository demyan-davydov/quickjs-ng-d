// Based on quickjs.h of QuickJS-NG (https://github.com/quickjs-ng/quickjs, v0.18.0).
// Copyright (c) 2017-2026 Fabrice Bellard, Charlie Gordon, Ben Noordhuis, Saul Ibarra Corretge
// and contributors. Distributed under the MIT License (see ../../LICENSE).
/// Low-level QuickJS-NG types. Mirrors quickjs.h of the vendored version (see VENDOR.md).
/// Only the 64-bit, non-NaN-boxing JSValue layout is supported.
module quickjs.types;

extern (C) nothrow:

static assert((void*).sizeof == 8,
    "quickjs-d supports 64-bit targets only (JS_NAN_BOXING layout is not bound)");

// ---- opaque types ----
struct JSRuntime;
struct JSContext;
struct JSObject;
struct JSModuleDef;
struct JSGCObjectHeader;
/// C `FILE` (opaque; only used behind pointers).
struct FILE;

alias JSClassID = uint;
alias JSAtom = uint;

// ---- JSValue ----
union JSValueUnion
{
    ulong uint64;
    double float64;
    void* ptr;
    int short_big_int;
}

/// 16 bytes on 64-bit targets: { union u; int64_t tag; }.
/// A JSValue is a plain handle: copying it does NOT touch the reference count.
struct JSValue
{
    JSValueUnion u;
    long tag;
}

/// In C, JSValueConst is `#define`d to JSValue. Kept as an alias for readability only;
/// it carries no ownership information.
alias JSValueConst = JSValue;

static assert(JSValueUnion.sizeof == 8 && JSValue.sizeof == 16 && JSValue.alignof == 8);
static assert(JSValue.u.offsetof == 0 && JSValue.tag.offsetof == 8);

// ---- callback types ----
alias JSCFunction = JSValue function(JSContext* ctx, JSValue this_val, int argc, JSValue* argv);
alias JSCFunctionMagic = JSValue function(JSContext* ctx, JSValue this_val, int argc, JSValue* argv, int magic);
alias JSCFunctionData = JSValue function(JSContext* ctx, JSValue this_val, int argc, JSValue* argv, int magic, JSValue* func_data);
alias JSCClosure = JSValue function(JSContext* ctx, JSValue this_val, int argc, JSValue* argv, int magic, void* opaque);
alias JSCClosureFinalizerFunc = void function(void*);

alias JS_MarkFunc = void function(JSRuntime* rt, JSGCObjectHeader* gp);
alias JSRuntimeFinalizer = void function(JSRuntime* rt, void* arg);
alias JSClassFinalizer = void function(JSRuntime* rt, JSValue val);
alias JSClassGCMark = void function(JSRuntime* rt, JSValue val, JS_MarkFunc mark_func);
alias JSClassCall = JSValue function(JSContext* ctx, JSValue func_obj, JSValue this_val, int argc, JSValue* argv, int flags);

alias JSJobFunc = JSValue function(JSContext* ctx, int argc, JSValue* argv);
alias JSInterruptHandler = int function(JSContext* ctx, void* opaque);
alias JSReallocArrayBufferDataFunc = void* function(JSRuntime* rt, void* opaque, void* ptr, size_t size);

alias JSModuleNormalizeFunc = char* function(JSContext* ctx, const(char)* module_base_name, const(char)* module_name, void* opaque);
alias JSModuleNormalizeFunc2 = char* function(JSContext* ctx, const(char)* module_base_name, const(char)* module_name, JSValue attributes, void* opaque);
alias JSModuleLoaderFunc = JSModuleDef* function(JSContext* ctx, const(char)* module_name, void* opaque);
alias JSModuleLoaderFunc2 = JSModuleDef* function(JSContext* ctx, const(char)* module_name, void* opaque, JSValue attributes);
alias JSModuleCheckSupportedImportAttributes = int function(JSContext* ctx, void* opaque, JSValue attributes);
alias JSDynamicImportFunc = void function(JSContext* ctx, const(char)* basename, const(char)* filename, JSValue token, JSValue attributes, void* opaque);
alias JSModuleInitFunc = int function(JSContext* ctx, JSModuleDef* m);

alias JSPromiseHook = void function(JSContext* ctx, JSPromiseHookType type, JSValue promise, JSValue parent_promise, void* opaque);
alias JSHostPromiseRejectionTracker = void function(JSContext* ctx, JSValue promise, JSValue reason, bool is_handled, void* opaque);

// ---- enums ----
enum JSPromiseHookType : int
{
    JS_PROMISE_HOOK_INIT,
    JS_PROMISE_HOOK_BEFORE,
    JS_PROMISE_HOOK_AFTER,
    JS_PROMISE_HOOK_RESOLVE,
}

enum JSPromiseStateEnum : int
{
    JS_PROMISE_NOT_A_PROMISE = -1,
    JS_PROMISE_PENDING = 0,
    JS_PROMISE_FULFILLED,
    JS_PROMISE_REJECTED,
}

enum JSTypedArrayEnum : int
{
    JS_TYPED_ARRAY_UINT8C = 0,
    JS_TYPED_ARRAY_INT8,
    JS_TYPED_ARRAY_UINT8,
    JS_TYPED_ARRAY_INT16,
    JS_TYPED_ARRAY_UINT16,
    JS_TYPED_ARRAY_INT32,
    JS_TYPED_ARRAY_UINT32,
    JS_TYPED_ARRAY_BIG_INT64,
    JS_TYPED_ARRAY_BIG_UINT64,
    JS_TYPED_ARRAY_FLOAT16,
    JS_TYPED_ARRAY_FLOAT32,
    JS_TYPED_ARRAY_FLOAT64,
}

enum JSCFunctionEnum : int
{
    JS_CFUNC_generic,
    JS_CFUNC_generic_magic,
    JS_CFUNC_constructor,
    JS_CFUNC_constructor_magic,
    JS_CFUNC_constructor_or_func,
    JS_CFUNC_constructor_or_func_magic,
    JS_CFUNC_f_f,
    JS_CFUNC_f_f_f,
    JS_CFUNC_getter,
    JS_CFUNC_setter,
    JS_CFUNC_getter_magic,
    JS_CFUNC_setter_magic,
    JS_CFUNC_iterator_next,
}

// ---- structs ----
struct JSMallocFunctions
{
    void* function(void* opaque, size_t count, size_t size) js_calloc;
    void* function(void* opaque, size_t size) js_malloc;
    void function(void* opaque, void* ptr) js_free;
    void* function(void* opaque, void* ptr, size_t size) js_realloc;
    size_t function(const(void)* ptr) js_malloc_usable_size;
}

struct JSMemoryUsage
{
    long malloc_size, malloc_limit, memory_used_size;
    long malloc_count;
    long memory_used_count;
    long atom_count, atom_size;
    long str_count, str_size;
    long obj_count, obj_size;
    long prop_count, prop_size;
    long shape_count, shape_size;
    long js_func_count, js_func_size, js_func_code_size;
    long js_func_pc2line_count, js_func_pc2line_size;
    long c_func_count, array_count;
    long fast_array_count, fast_array_elements;
    long binary_object_count, binary_object_size;
}

struct JSPropertyEnum
{
    bool is_enumerable;
    JSAtom atom;
}

struct JSPropertyDescriptor
{
    int flags;
    JSValue value;
    JSValue getter;
    JSValue setter;
}

struct JSClassExoticMethods
{
    int function(JSContext* ctx, JSPropertyDescriptor* desc, JSValue obj, JSAtom prop) get_own_property;
    int function(JSContext* ctx, JSPropertyEnum** ptab, uint* plen, JSValue obj) get_own_property_names;
    int function(JSContext* ctx, JSValue obj, JSAtom prop) delete_property;
    int function(JSContext* ctx, JSValue this_obj, JSAtom prop, JSValue val, JSValue getter, JSValue setter, int flags) define_own_property;
    int function(JSContext* ctx, JSValue obj, JSAtom atom) has_property;
    JSValue function(JSContext* ctx, JSValue obj, JSAtom atom, JSValue receiver) get_property;
    int function(JSContext* ctx, JSValue obj, JSAtom atom, JSValue value, JSValue receiver, int flags) set_property;
}

struct JSClassDef
{
    const(char)* class_name; /// pure ASCII only
    JSClassFinalizer finalizer;
    JSClassGCMark gc_mark;
    JSClassCall call;
    JSClassExoticMethods* exotic;
}

struct JSEvalOptions
{
    int version_;      // C: `version`
    int eval_flags;
    const(char)* filename;
    int line_num;
}

struct JSSABTab
{
    ubyte** tab;
    size_t len;
}

struct JSSharedArrayBufferFunctions
{
    void* function(void* opaque, size_t size) sab_alloc;
    void function(void* opaque, void* ptr) sab_free;
    void function(void* opaque, void* ptr) sab_dup;
    void* sab_opaque;
}

union JSCFunctionType
{
    JSCFunction generic;
    JSValue function(JSContext*, JSValue this_val, int argc, JSValue* argv, int magic) generic_magic;
    JSCFunction constructor;
    JSValue function(JSContext*, JSValue new_target, int argc, JSValue* argv, int magic) constructor_magic;
    JSCFunction constructor_or_func;
    double function(double) f_f;
    double function(double, double) f_f_f;
    JSValue function(JSContext*, JSValue this_val) getter;
    JSValue function(JSContext*, JSValue this_val, JSValue val) setter;
    JSValue function(JSContext*, JSValue this_val, int magic) getter_magic;
    JSValue function(JSContext*, JSValue this_val, JSValue val, int magic) setter_magic;
    JSValue function(JSContext*, JSValue this_val, int argc, JSValue* argv, int* pdone, int magic) iterator_next;
}

struct JSCFunctionListEntry_Func
{
    ubyte length;
    ubyte cproto;
    JSCFunctionType cfunc;
}

struct JSCFunctionListEntry_GetSet
{
    JSCFunctionType get;
    JSCFunctionType set;
}

struct JSCFunctionListEntry_Alias
{
    const(char)* name;
    int base;
}

struct JSCFunctionListEntry_PropList
{
    const(JSCFunctionListEntry)* tab;
    int len;
}

union JSCFunctionListEntryUnion
{
    JSCFunctionListEntry_Func func;
    JSCFunctionListEntry_GetSet getset;
    JSCFunctionListEntry_Alias alias_;      // C: `alias`
    JSCFunctionListEntry_PropList prop_list;
    const(char)* str;
    int i32;
    long i64;
    ulong u64;
    double f64;
}

struct JSCFunctionListEntry
{
    const(char)* name;
    ubyte prop_flags;
    ubyte def_type;
    short magic;
    JSCFunctionListEntryUnion u;
}
