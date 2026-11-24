// Based on quickjs.h of QuickJS-NG (https://github.com/quickjs-ng/quickjs, v0.18.0).
// Copyright (c) 2017-2026 Fabrice Bellard, Charlie Gordon, Ben Noordhuis, Saul Ibarra Corretge
// and contributors. Distributed under the MIT License (see ../../LICENSE).
/// Low-level binding of the public QuickJS-NG C API (quickjs.h).
///
/// Ownership rules are those of the C API and are NOT enforced here:
///  * a function taking `JSValue` (by the C declaration) takes ownership of the argument;
///  * a function taking `JSValueConst` borrows it;
///  * a function returning `JSValue` transfers ownership to the caller (call JS_FreeValue).
/// The D type of both is the same struct; the distinction is documented per parameter by
/// the parameter name (`val` = owned, otherwise borrowed) only where it matters.
module quickjs_ng.c_api;

public import quickjs_ng.types;
public import quickjs_ng.constants;

// -------------------------------------------------------------------------------------
// Functions that are `static inline` in quickjs.h are re-implemented here in D.
// They are not linkable symbols in the C library.
// -------------------------------------------------------------------------------------
nothrow @nogc pragma(inline, true)
{
    JSValue JS_MKVAL(long tag, int val) pure @safe
    {
        JSValue v;
        v.u.uint64 = cast(uint) val;
        v.tag = tag;
        return v;
    }

    JSValue JS_MKPTR(long tag, void* ptr) pure @trusted
    {
        JSValue v;
        v.u.ptr = ptr;
        v.tag = tag;
        return v;
    }

    int JS_VALUE_GET_TAG(JSValue v) pure @safe { return cast(int) v.tag; }
    int JS_VALUE_GET_NORM_TAG(JSValue v) pure @safe { return cast(int) v.tag; }
    int JS_VALUE_GET_INT(JSValue v) pure @safe { return cast(int) v.u.uint64; }
    int JS_VALUE_GET_BOOL(JSValue v) pure @safe { return cast(int) v.u.uint64; }
    double JS_VALUE_GET_FLOAT64(JSValue v) pure @trusted { return v.u.float64; }
    int JS_VALUE_GET_SHORT_BIG_INT(JSValue v) pure @safe { return cast(int) v.u.uint64; }
    void* JS_VALUE_GET_PTR(JSValue v) pure @trusted { return v.u.ptr; }

    bool JS_TAG_IS_FLOAT64(int tag) pure @safe { return cast(uint) tag == JS_TAG_FLOAT64; }
    bool JS_VALUE_HAS_REF_COUNT(JSValue v) pure @safe
    {
        return cast(uint) JS_VALUE_GET_TAG(v) >= cast(uint) JS_TAG_FIRST;
    }

    /// `JS_NAN`, `JS_NULL`, ... are macros in C; here they are functions.
    JSValue JS_NAN() pure @trusted
    {
        JSValue v;
        v.u.float64 = double.nan;
        v.tag = JS_TAG_FLOAT64;
        return v;
    }
    JSValue JS_NULL() pure @safe { return JS_MKVAL(JS_TAG_NULL, 0); }
    JSValue JS_UNDEFINED() pure @safe { return JS_MKVAL(JS_TAG_UNDEFINED, 0); }
    JSValue JS_FALSE() pure @safe { return JS_MKVAL(JS_TAG_BOOL, 0); }
    JSValue JS_TRUE() pure @safe { return JS_MKVAL(JS_TAG_BOOL, 1); }
    JSValue JS_EXCEPTION() pure @safe { return JS_MKVAL(JS_TAG_EXCEPTION, 0); }
    JSValue JS_UNINITIALIZED() pure @safe { return JS_MKVAL(JS_TAG_UNINITIALIZED, 0); }

    JSValue __JS_NewFloat64(double d) pure @trusted
    {
        JSValue v;
        v.tag = JS_TAG_FLOAT64;
        v.u.float64 = d;
        return v;
    }

    bool JS_VALUE_IS_NAN(JSValue v) pure @trusted
    {
        if (v.tag != JS_TAG_FLOAT64)
            return false;
        return (v.u.uint64 & 0x7fffffffffffffffUL) > 0x7ff0000000000000UL;
    }

    JSValue JS_NewBool(JSContext* ctx, bool val) pure @safe { return JS_MKVAL(JS_TAG_BOOL, val ? 1 : 0); }
    JSValue JS_NewInt32(JSContext* ctx, int val) pure @safe { return JS_MKVAL(JS_TAG_INT, val); }
    JSValue JS_NewFloat64(JSContext* ctx, double val) pure @safe { return __JS_NewFloat64(val); }
    JSValue JS_NewCatchOffset(JSContext* ctx, int val) pure @safe { return JS_MKVAL(JS_TAG_CATCH_OFFSET, val); }

    JSValue JS_NewInt64(JSContext* ctx, long val) pure @safe
    {
        if (val >= int.min && val <= int.max)
            return JS_NewInt32(ctx, cast(int) val);
        return JS_NewFloat64(ctx, cast(double) val);
    }

    JSValue JS_NewUint32(JSContext* ctx, uint val) pure @safe
    {
        if (val <= int.max)
            return JS_NewInt32(ctx, cast(int) val);
        return JS_NewFloat64(ctx, cast(double) val);
    }

    JSValue JS_NewUint64(JSContext* ctx, ulong val) pure @safe
    {
        if (val <= int.max)
            return JS_NewInt32(ctx, cast(int) val);
        return JS_NewFloat64(ctx, cast(double) val);
    }

    bool JS_IsNumber(JSValue v) pure @safe
    {
        const tag = JS_VALUE_GET_TAG(v);
        return tag == JS_TAG_INT || JS_TAG_IS_FLOAT64(tag);
    }
    bool JS_IsBigInt(JSValue v) pure @safe
    {
        const tag = JS_VALUE_GET_TAG(v);
        return tag == JS_TAG_BIG_INT || tag == JS_TAG_SHORT_BIG_INT;
    }
    bool JS_IsBool(JSValue v) pure @safe { return JS_VALUE_GET_TAG(v) == JS_TAG_BOOL; }
    bool JS_IsNull(JSValue v) pure @safe { return JS_VALUE_GET_TAG(v) == JS_TAG_NULL; }
    bool JS_IsUndefined(JSValue v) pure @safe { return JS_VALUE_GET_TAG(v) == JS_TAG_UNDEFINED; }
    bool JS_IsException(JSValue v) pure @safe { return JS_VALUE_GET_TAG(v) == JS_TAG_EXCEPTION; }
    bool JS_IsUninitialized(JSValue v) pure @safe { return JS_VALUE_GET_TAG(v) == JS_TAG_UNINITIALIZED; }
    bool JS_IsString(JSValue v) pure @safe
    {
        const tag = JS_VALUE_GET_TAG(v);
        return tag == JS_TAG_STRING || tag == JS_TAG_STRING_ROPE;
    }
    bool JS_IsSymbol(JSValue v) pure @safe { return JS_VALUE_GET_TAG(v) == JS_TAG_SYMBOL; }
    bool JS_IsObject(JSValue v) pure @safe { return JS_VALUE_GET_TAG(v) == JS_TAG_OBJECT; }
    bool JS_IsModule(JSValue v) pure @safe { return JS_VALUE_GET_TAG(v) == JS_TAG_MODULE; }
}

// -------------------------------------------------------------------------------------
// Exported C functions
// -------------------------------------------------------------------------------------
extern (C) nothrow @nogc:

// ---- runtime ----
JSRuntime* JS_NewRuntime();
void JS_SetRuntimeInfo(JSRuntime* rt, const(char)* info);
void JS_SetMemoryLimit(JSRuntime* rt, size_t limit);
void JS_SetDumpFlags(JSRuntime* rt, ulong flags);
ulong JS_GetDumpFlags(JSRuntime* rt);
size_t JS_GetGCThreshold(JSRuntime* rt);
void JS_SetGCThreshold(JSRuntime* rt, size_t gc_threshold);
void JS_SetMaxStackSize(JSRuntime* rt, size_t stack_size);
void JS_UpdateStackTop(JSRuntime* rt);
JSRuntime* JS_NewRuntime2(const(JSMallocFunctions)* mf, void* opaque);
void JS_FreeRuntime(JSRuntime* rt);
void* JS_GetRuntimeOpaque(JSRuntime* rt);
void JS_SetRuntimeOpaque(JSRuntime* rt, void* opaque);
int JS_AddRuntimeFinalizer(JSRuntime* rt, JSRuntimeFinalizer finalizer, void* arg);
void JS_MarkValue(JSRuntime* rt, JSValue val, JS_MarkFunc mark_func);
void JS_RunGC(JSRuntime* rt);
bool JS_IsLiveObject(JSRuntime* rt, JSValue obj);

// ---- context ----
JSContext* JS_NewContext(JSRuntime* rt);
void JS_FreeContext(JSContext* s);
JSContext* JS_DupContext(JSContext* ctx);
void* JS_GetContextOpaque(JSContext* ctx);
void JS_SetContextOpaque(JSContext* ctx, void* opaque);
JSRuntime* JS_GetRuntime(JSContext* ctx);
void JS_SetClassProto(JSContext* ctx, JSClassID class_id, JSValue obj /* owned */);
JSValue JS_GetClassProto(JSContext* ctx, JSClassID class_id);
JSValue JS_GetFunctionProto(JSContext* ctx);

JSContext* JS_NewContextRaw(JSRuntime* rt);
int JS_AddIntrinsicBaseObjects(JSContext* ctx);
int JS_AddIntrinsicDate(JSContext* ctx);
int JS_AddIntrinsicEval(JSContext* ctx);
void JS_AddIntrinsicRegExpCompiler(JSContext* ctx);
int JS_AddIntrinsicRegExp(JSContext* ctx);
int JS_AddIntrinsicJSON(JSContext* ctx);
int JS_AddIntrinsicProxy(JSContext* ctx);
int JS_AddIntrinsicMapSet(JSContext* ctx);
int JS_AddIntrinsicTypedArrays(JSContext* ctx);
int JS_AddIntrinsicPromise(JSContext* ctx);
int JS_AddIntrinsicBigInt(JSContext* ctx);
int JS_AddIntrinsicWeakRef(JSContext* ctx);
int JS_AddPerformance(JSContext* ctx);
int JS_AddIntrinsicDOMException(JSContext* ctx);
int JS_AddIntrinsicAToB(JSContext* ctx);

// ---- comparison ----
int JS_IsEqual(JSContext* ctx, JSValue op1, JSValue op2);
bool JS_IsStrictEqual(JSContext* ctx, JSValue op1, JSValue op2);
bool JS_IsSameValue(JSContext* ctx, JSValue op1, JSValue op2);
bool JS_IsSameValueZero(JSContext* ctx, JSValue op1, JSValue op2);

// ---- memory ----
void* js_calloc_rt(JSRuntime* rt, size_t count, size_t size);
void* js_malloc_rt(JSRuntime* rt, size_t size);
void js_free_rt(JSRuntime* rt, void* ptr);
void* js_realloc_rt(JSRuntime* rt, void* ptr, size_t size);
size_t js_malloc_usable_size_rt(JSRuntime* rt, const(void)* ptr);
void* js_mallocz_rt(JSRuntime* rt, size_t size);
void* js_calloc(JSContext* ctx, size_t count, size_t size);
void* js_malloc(JSContext* ctx, size_t size);
void js_free(JSContext* ctx, void* ptr);
void* js_realloc(JSContext* ctx, void* ptr, size_t size);
size_t js_malloc_usable_size(JSContext* ctx, const(void)* ptr);
void* js_mallocz(JSContext* ctx, size_t size);
char* js_strdup(JSContext* ctx, const(char)* str);
char* js_strndup(JSContext* ctx, const(char)* s, size_t n);
void JS_ComputeMemoryUsage(JSRuntime* rt, JSMemoryUsage* s);
void JS_DumpMemoryUsage(FILE* fp, const(JSMemoryUsage)* s, JSRuntime* rt);

// ---- atoms ----
JSAtom JS_NewAtomLen(JSContext* ctx, const(char)* str, size_t len);
JSAtom JS_NewAtom(JSContext* ctx, const(char)* str);
JSAtom JS_NewAtomUInt32(JSContext* ctx, uint n);
JSAtom JS_DupAtom(JSContext* ctx, JSAtom v);
JSAtom JS_DupAtomRT(JSRuntime* rt, JSAtom v);
void JS_FreeAtom(JSContext* ctx, JSAtom v);
void JS_FreeAtomRT(JSRuntime* rt, JSAtom v);
JSValue JS_AtomToValue(JSContext* ctx, JSAtom atom);
JSValue JS_AtomToString(JSContext* ctx, JSAtom atom);
const(char)* JS_AtomToCStringLen(JSContext* ctx, size_t* plen, JSAtom atom);
JSAtom JS_ValueToAtom(JSContext* ctx, JSValue val);

// ---- classes ----
JSClassID JS_NewClassID(JSRuntime* rt, JSClassID* pclass_id);
JSClassID JS_GetClassID(JSValue v);
int JS_NewClass(JSRuntime* rt, JSClassID class_id, const(JSClassDef)* class_def);
bool JS_IsRegisteredClass(JSRuntime* rt, JSClassID class_id);
JSAtom JS_GetClassName(JSRuntime* rt, JSClassID class_id);

// ---- numbers ----
JSValue JS_NewNumber(JSContext* ctx, double d);
JSValue JS_NewBigInt64(JSContext* ctx, long v);
JSValue JS_NewBigUint64(JSContext* ctx, ulong v);

// ---- exceptions ----
JSValue JS_Throw(JSContext* ctx, JSValue obj /* owned */);
JSValue JS_GetException(JSContext* ctx);
bool JS_HasException(JSContext* ctx);
bool JS_IsError(JSValue val);
bool JS_IsUncatchableError(JSValue val);
void JS_SetUncatchableError(JSContext* ctx, JSValue val);
void JS_ClearUncatchableError(JSContext* ctx, JSValue val);
void JS_ResetUncatchableError(JSContext* ctx);
JSValue JS_NewError(JSContext* ctx);
JSValue JS_NewInternalError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_NewPlainError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_NewRangeError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_NewReferenceError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_NewSyntaxError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_NewTypeError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_ThrowInternalError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_ThrowPlainError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_ThrowRangeError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_ThrowReferenceError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_ThrowSyntaxError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_ThrowTypeError(JSContext* ctx, const(char)* fmt, ...);
JSValue JS_ThrowDOMException(JSContext* ctx, const(char)* name, const(char)* fmt, ...);
JSValue JS_ThrowOutOfMemory(JSContext* ctx);

// ---- reference counting ----
void JS_FreeValue(JSContext* ctx, JSValue v);
void JS_FreeValueRT(JSRuntime* rt, JSValue v);
JSValue JS_DupValue(JSContext* ctx, JSValue v);
JSValue JS_DupValueRT(JSRuntime* rt, JSValue v);

// ---- conversions ----
int JS_ToBool(JSContext* ctx, JSValue val);
JSValue JS_ToNumber(JSContext* ctx, JSValue val);
int JS_ToInt32(JSContext* ctx, int* pres, JSValue val);
int JS_ToInt64(JSContext* ctx, long* pres, JSValue val);
int JS_ToIndex(JSContext* ctx, ulong* plen, JSValue val);
int JS_ToFloat64(JSContext* ctx, double* pres, JSValue val);
int JS_ToBigInt64(JSContext* ctx, long* pres, JSValue val);
int JS_ToBigUint64(JSContext* ctx, ulong* pres, JSValue val);
int JS_ToInt64Ext(JSContext* ctx, long* pres, JSValue val);

// ---- strings ----
JSValue JS_NewStringLen(JSContext* ctx, const(char)* str1, size_t len1);
JSValue JS_NewStringUTF16(JSContext* ctx, const(ushort)* buf, size_t len);
JSValue JS_NewAtomString(JSContext* ctx, const(char)* str);
JSValue JS_ToString(JSContext* ctx, JSValue val);
JSValue JS_ToPropertyKey(JSContext* ctx, JSValue val);
const(char)* JS_ToCStringLen2(JSContext* ctx, size_t* plen, JSValue val1, bool cesu8);
const(ushort)* JS_ToCStringLenUTF16(JSContext* ctx, size_t* plen, JSValue val1);
void JS_FreeCString(JSContext* ctx, const(char)* ptr);
void JS_FreeCStringRT(JSRuntime* rt, const(char)* ptr);
void JS_FreeCStringUTF16(JSContext* ctx, const(ushort)* ptr);
void JS_FreeCStringRT_UTF16(JSRuntime* rt, const(ushort)* ptr);

// ---- objects ----
JSValue JS_NewObjectProtoClass(JSContext* ctx, JSValue proto, JSClassID class_id);
JSValue JS_NewObjectClass(JSContext* ctx, JSClassID class_id);
JSValue JS_NewObjectProto(JSContext* ctx, JSValue proto);
JSValue JS_NewObject(JSContext* ctx);
JSValue JS_NewObjectFrom(JSContext* ctx, int count, const(JSAtom)* props, const(JSValue)* values);
JSValue JS_NewObjectFromStr(JSContext* ctx, int count, const(char)** props, const(JSValue)* values);
JSValue JS_ToObject(JSContext* ctx, JSValue val);
JSValue JS_ToObjectString(JSContext* ctx, JSValue val);

bool JS_IsFunction(JSContext* ctx, JSValue val);
bool JS_IsAsyncFunction(JSValue val);
bool JS_IsConstructor(JSContext* ctx, JSValue val);
bool JS_SetConstructorBit(JSContext* ctx, JSValue func_obj, bool val);
bool JS_IsRegExp(JSValue val);
bool JS_IsMap(JSValue val);
bool JS_IsSet(JSValue val);
bool JS_IsWeakRef(JSValue val);
bool JS_IsWeakSet(JSValue val);
bool JS_IsWeakMap(JSValue val);
bool JS_IsDataView(JSValue val);

JSValue JS_NewArray(JSContext* ctx);
JSValue JS_NewArrayFrom(JSContext* ctx, int count, const(JSValue)* values);
bool JS_IsArray(JSValue val);
bool JS_IsProxy(JSValue val);
JSValue JS_GetProxyTarget(JSContext* ctx, JSValue proxy);
JSValue JS_GetProxyHandler(JSContext* ctx, JSValue proxy);
JSValue JS_NewProxy(JSContext* ctx, JSValue target, JSValue handler);
JSValue JS_NewDate(JSContext* ctx, double epoch_ms);
bool JS_IsDate(JSValue v);

// ---- properties ----
JSValue JS_GetProperty(JSContext* ctx, JSValue this_obj, JSAtom prop);
JSValue JS_GetPropertyUint32(JSContext* ctx, JSValue this_obj, uint idx);
JSValue JS_GetPropertyInt64(JSContext* ctx, JSValue this_obj, long idx);
JSValue JS_GetPropertyStr(JSContext* ctx, JSValue this_obj, const(char)* prop);
JSValue JS_GetPropertyValue(JSContext* ctx, JSValue this_obj, JSValue prop /* owned */);
int JS_SetProperty(JSContext* ctx, JSValue this_obj, JSAtom prop, JSValue val /* owned */);
int JS_SetPropertyUint32(JSContext* ctx, JSValue this_obj, uint idx, JSValue val /* owned */);
int JS_SetPropertyInt64(JSContext* ctx, JSValue this_obj, long idx, JSValue val /* owned */);
int JS_SetPropertyStr(JSContext* ctx, JSValue this_obj, const(char)* prop, JSValue val /* owned */);
int JS_SetPropertyValue(JSContext* ctx, JSValue this_obj, JSValue prop /* owned */, JSValue val /* owned */, int flags);
int JS_HasProperty(JSContext* ctx, JSValue this_obj, JSAtom prop);
int JS_IsExtensible(JSContext* ctx, JSValue obj);
int JS_PreventExtensions(JSContext* ctx, JSValue obj);
int JS_DeleteProperty(JSContext* ctx, JSValue obj, JSAtom prop, int flags);
int JS_SetPrototype(JSContext* ctx, JSValue obj, JSValue proto_val);
JSValue JS_GetPrototype(JSContext* ctx, JSValue val);
int JS_GetLength(JSContext* ctx, JSValue obj, long* pres);
int JS_SetLength(JSContext* ctx, JSValue obj, long len);
int JS_SealObject(JSContext* ctx, JSValue obj);
int JS_FreezeObject(JSContext* ctx, JSValue obj);
int JS_GetOwnPropertyNames(JSContext* ctx, JSPropertyEnum** ptab, uint* plen, JSValue obj, int flags);
int JS_GetOwnProperty(JSContext* ctx, JSPropertyDescriptor* desc, JSValue obj, JSAtom prop);
void JS_FreePropertyEnum(JSContext* ctx, JSPropertyEnum* tab, uint len);
int JS_DefineProperty(JSContext* ctx, JSValue this_obj, JSAtom prop, JSValue val, JSValue getter, JSValue setter, int flags);
int JS_DefinePropertyValue(JSContext* ctx, JSValue this_obj, JSAtom prop, JSValue val /* owned */, int flags);
int JS_DefinePropertyValueUint32(JSContext* ctx, JSValue this_obj, uint idx, JSValue val /* owned */, int flags);
int JS_DefinePropertyValueStr(JSContext* ctx, JSValue this_obj, const(char)* prop, JSValue val /* owned */, int flags);
int JS_DefinePropertyGetSet(JSContext* ctx, JSValue this_obj, JSAtom prop, JSValue getter /* owned */, JSValue setter /* owned */, int flags);

// ---- calls / eval ----
JSValue JS_Call(JSContext* ctx, JSValue func_obj, JSValue this_obj, int argc, JSValue* argv);
JSValue JS_Invoke(JSContext* ctx, JSValue this_val, JSAtom atom, int argc, JSValue* argv);
JSValue JS_CallConstructor(JSContext* ctx, JSValue func_obj, int argc, JSValue* argv);
JSValue JS_CallConstructor2(JSContext* ctx, JSValue func_obj, JSValue new_target, int argc, JSValue* argv);
bool JS_DetectModule(const(char)* input, size_t input_len);
/// `input` must be zero terminated: input[input_len] == '\0'.
JSValue JS_Eval(JSContext* ctx, const(char)* input, size_t input_len, const(char)* filename, int eval_flags);
JSValue JS_Eval2(JSContext* ctx, const(char)* input, size_t input_len, JSEvalOptions* options);
JSValue JS_EvalThis(JSContext* ctx, JSValue this_obj, const(char)* input, size_t input_len, const(char)* filename, int eval_flags);
JSValue JS_EvalThis2(JSContext* ctx, JSValue this_obj, const(char)* input, size_t input_len, JSEvalOptions* options);
JSValue JS_GetGlobalObject(JSContext* ctx);
int JS_IsInstanceOf(JSContext* ctx, JSValue val, JSValue obj);

// ---- opaque ----
int JS_SetOpaque(JSValue obj, void* opaque);
void* JS_GetOpaque(JSValue obj, JSClassID class_id);
void* JS_GetOpaque2(JSContext* ctx, JSValue obj, JSClassID class_id);
void* JS_GetAnyOpaque(JSValue obj, JSClassID* class_id);

// ---- JSON ----
JSValue JS_ParseJSON(JSContext* ctx, const(char)* buf, size_t buf_len, const(char)* filename);
JSValue JS_JSONStringify(JSContext* ctx, JSValue obj, JSValue replacer, JSValue space0);

// ---- array buffers / typed arrays ----
JSValue JS_NewArrayBuffer(JSContext* ctx, ubyte* buf, size_t len, size_t max_len,
    JSReallocArrayBufferDataFunc realloc_func, void* opaque, bool is_shared);
JSValue JS_NewArrayBufferCopy(JSContext* ctx, const(ubyte)* buf, size_t len);
void JS_DetachArrayBuffer(JSContext* ctx, JSValue obj);
ubyte* JS_GetArrayBuffer(JSContext* ctx, size_t* psize, JSValue obj);
bool JS_IsArrayBuffer(JSValue obj);
int JS_IsImmutableArrayBuffer(JSValue obj);
int JS_SetImmutableArrayBuffer(JSValue obj, bool immutable_);
ubyte* JS_GetUint8Array(JSContext* ctx, size_t* psize, JSValue obj);
JSValue JS_NewTypedArray(JSContext* ctx, int argc, JSValue* argv, JSTypedArrayEnum array_type);
JSValue JS_GetTypedArrayBuffer(JSContext* ctx, JSValue obj, size_t* pbyte_offset, size_t* pbyte_length, size_t* pbytes_per_element);
JSValue JS_NewUint8Array(JSContext* ctx, ubyte* buf, size_t len, JSReallocArrayBufferDataFunc realloc_func, void* opaque, bool is_shared);
int JS_GetTypedArrayType(JSValue obj);
JSValue JS_NewUint8ArrayCopy(JSContext* ctx, const(ubyte)* buf, size_t len);
void JS_SetSharedArrayBufferFunctions(JSRuntime* rt, const(JSSharedArrayBufferFunctions)* sf);

// ---- promises / symbols ----
JSValue JS_NewPromiseCapability(JSContext* ctx, JSValue* resolving_funcs);
JSValue JS_PromiseThen(JSContext* ctx, JSValue promise, JSValue on_fulfilled, JSValue on_rejected);
JSPromiseStateEnum JS_PromiseState(JSContext* ctx, JSValue promise);
JSValue JS_PromiseResult(JSContext* ctx, JSValue promise);
bool JS_IsPromise(JSValue val);
void JS_PromiseMarkAsHandled(JSContext* ctx, JSValue promise);
JSValue JS_NewSettledPromise(JSContext* ctx, bool is_reject, JSValue value);
JSValue JS_NewSymbol(JSContext* ctx, const(char)* description, bool is_global);
JSValue JS_NewPrivateSymbol(JSContext* ctx, const(char)* description);
void JS_SetPromiseHook(JSRuntime* rt, JSPromiseHook promise_hook, void* opaque);
void JS_SetHostPromiseRejectionTracker(JSRuntime* rt, JSHostPromiseRejectionTracker cb, void* opaque);

// ---- runtime hooks ----
void JS_SetInterruptHandler(JSRuntime* rt, JSInterruptHandler cb, void* opaque);
void JS_SetCanBlock(JSRuntime* rt, bool can_block);
void JS_SetIsHTMLDDA(JSContext* ctx, JSValue obj);

// ---- modules ----
void JS_SetModuleLoaderFunc(JSRuntime* rt, JSModuleNormalizeFunc module_normalize, JSModuleLoaderFunc module_loader, void* opaque);
void JS_SetModuleLoaderFunc2(JSRuntime* rt, JSModuleNormalizeFunc module_normalize, JSModuleLoaderFunc2 module_loader,
    JSModuleCheckSupportedImportAttributes module_check_attrs, void* opaque);
void JS_SetDynamicImportFunc(JSRuntime* rt, JSDynamicImportFunc func, void* opaque);
void JS_SetModuleNormalizeFunc2(JSRuntime* rt, JSModuleNormalizeFunc2 module_normalize, void* opaque);
int JS_FinishDynamicImport(JSContext* ctx, JSValue token, JSValue promise, JSValue result);
JSValue JS_GetImportMeta(JSContext* ctx, JSModuleDef* m);
JSAtom JS_GetModuleName(JSContext* ctx, JSModuleDef* m);
JSValue JS_GetModuleNamespace(JSContext* ctx, JSModuleDef* m);
int JS_SetModulePrivateValue(JSContext* ctx, JSModuleDef* m, JSValue val /* owned */);
JSValue JS_GetModulePrivateValue(JSContext* ctx, JSModuleDef* m);
JSValue JS_EvalFunction(JSContext* ctx, JSValue fun_obj /* owned */);
int JS_ResolveModule(JSContext* ctx, JSValue obj);
JSAtom JS_GetScriptOrModuleName(JSContext* ctx, int n_stack_levels);
JSValue JS_LoadModule(JSContext* ctx, const(char)* basename, const(char)* filename, JSValue attributes);
JSModuleDef* JS_NewCModule(JSContext* ctx, const(char)* name_str, JSModuleInitFunc func);
int JS_AddModuleExport(JSContext* ctx, JSModuleDef* m, const(char)* name_str);
int JS_AddModuleExportList(JSContext* ctx, JSModuleDef* m, const(JSCFunctionListEntry)* tab, int len);
int JS_SetModuleExport(JSContext* ctx, JSModuleDef* m, const(char)* export_name, JSValue val /* owned */);
int JS_SetModuleExportList(JSContext* ctx, JSModuleDef* m, const(JSCFunctionListEntry)* tab, int len);

// ---- jobs ----
int JS_EnqueueJob(JSContext* ctx, JSJobFunc job_func, int argc, JSValue* argv);
bool JS_IsJobPending(JSRuntime* rt);
JSContext* JS_GetPendingJobContext(JSRuntime* rt);
int JS_ExecutePendingJob(JSRuntime* rt, JSContext** pctx);

// ---- (de)serialization ----
ubyte* JS_WriteObject(JSContext* ctx, size_t* psize, JSValue obj, int flags);
ubyte* JS_WriteObject2(JSContext* ctx, size_t* psize, JSValue obj, int flags, JSSABTab* psab_tab);
JSValue JS_ReadObject(JSContext* ctx, const(ubyte)* buf, size_t buf_len, int flags);
JSValue JS_ReadObject2(JSContext* ctx, const(ubyte)* buf, size_t buf_len, int flags, JSSABTab* psab_tab);

// ---- C functions ----
JSValue JS_NewCFunction2(JSContext* ctx, JSCFunction func, const(char)* name, int length, JSCFunctionEnum cproto, int magic);
JSValue JS_NewCFunction3(JSContext* ctx, JSCFunction func, const(char)* name, int length, JSCFunctionEnum cproto, int magic,
    JSValue proto_val, int n_fields);
JSValue JS_NewCFunctionData(JSContext* ctx, JSCFunctionData func, int length, int magic, int data_len, JSValue* data);
JSValue JS_NewCFunctionData2(JSContext* ctx, JSCFunctionData func, const(char)* name, int length, int magic, int data_len, JSValue* data);
JSValue JS_NewCClosure(JSContext* ctx, JSCClosure func, const(char)* name, JSCClosureFinalizerFunc opaque_finalize,
    int length, int magic, void* opaque);
int JS_SetConstructor(JSContext* ctx, JSValue func_obj, JSValue proto);
int JS_SetPropertyFunctionList(JSContext* ctx, JSValue obj, const(JSCFunctionListEntry)* tab, int len);

// ---- version ----
const(char)* JS_GetVersion();

// -------------------------------------------------------------------------------------
// D-linkage wrappers for the remaining `static inline` helpers
// -------------------------------------------------------------------------------------
extern (D) nothrow @nogc
{
    JSValue JS_ToBoolean(JSContext* ctx, JSValue val) { return JS_NewBool(ctx, JS_ToBool(ctx, val) != 0); }
    int JS_ToUint32(JSContext* ctx, uint* pres, JSValue val) { return JS_ToInt32(ctx, cast(int*) pres, val); }
    JSValue JS_NewString(JSContext* ctx, const(char)* str)
    {
        import core.stdc.string : strlen;
        return JS_NewStringLen(ctx, str, strlen(str));
    }
    const(char)* JS_ToCStringLen(JSContext* ctx, size_t* plen, JSValue val1) { return JS_ToCStringLen2(ctx, plen, val1, false); }
    const(char)* JS_ToCString(JSContext* ctx, JSValue val1) { return JS_ToCStringLen2(ctx, null, val1, false); }
    const(ushort)* JS_ToCStringUTF16(JSContext* ctx, JSValue val1) { return JS_ToCStringLenUTF16(ctx, null, val1); }
    const(char)* JS_AtomToCString(JSContext* ctx, JSAtom atom) { return JS_AtomToCStringLen(ctx, null, atom); }
    JSValue JS_NewCFunction(JSContext* ctx, JSCFunction func, const(char)* name, int length)
    {
        return JS_NewCFunction2(ctx, func, name, length, JSCFunctionEnum.JS_CFUNC_generic, 0);
    }
    JSValue JS_NewCFunctionMagic(JSContext* ctx, JSCFunctionMagic func, const(char)* name, int length,
        JSCFunctionEnum cproto, int magic)
    {
        JSCFunctionType ft;
        ft.generic_magic = func;
        return JS_NewCFunction2(ctx, ft.generic, name, length, cproto, magic);
    }
}
