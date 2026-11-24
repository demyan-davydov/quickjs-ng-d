/* ABI probe: reports sizes/offsets/constants of the vendored quickjs.h so the D binding can
 * be verified against the real C compiler's view (see tests/abi.d). Compiled into the
 * native library together with QuickJS-NG. */
#include <stddef.h>
#include "quickjs.h"

enum {
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
    ID_COUNT
};

/* All values are exposed as long long for a trivial D-side signature. */
long long qjsd_abi_value(int id)
{
    switch (id) {
    case ID_SIZEOF_JSVALUE: return sizeof(JSValue);
    case ID_ALIGNOF_JSVALUE: return _Alignof(JSValue);
    case ID_OFFSETOF_TAG: return offsetof(JSValue, tag);
    case ID_SIZEOF_JSVALUEUNION: return sizeof(JSValueUnion);
    case ID_SIZEOF_CFUNCTIONTYPE: return sizeof(JSCFunctionType);
    case ID_SIZEOF_CFUNCTIONLISTENTRY: return sizeof(JSCFunctionListEntry);
    case ID_OFFSETOF_CFLE_U: return offsetof(JSCFunctionListEntry, u);
    case ID_SIZEOF_CLASSDEF: return sizeof(JSClassDef);
    case ID_SIZEOF_EXOTIC: return sizeof(JSClassExoticMethods);
    case ID_SIZEOF_MEMUSAGE: return sizeof(JSMemoryUsage);
    case ID_SIZEOF_PROPDESC: return sizeof(JSPropertyDescriptor);
    case ID_SIZEOF_PROPENUM: return sizeof(JSPropertyEnum);
    case ID_OFFSETOF_PROPENUM_ATOM: return offsetof(JSPropertyEnum, atom);
    case ID_SIZEOF_MALLOCFUNCS: return sizeof(JSMallocFunctions);
    case ID_SIZEOF_EVALOPTIONS: return sizeof(JSEvalOptions);
    case ID_OFFSETOF_EVALOPTIONS_FILENAME: return offsetof(JSEvalOptions, filename);
    case ID_SIZEOF_SABTAB: return sizeof(JSSABTab);
    case ID_SIZEOF_SABFUNCS: return sizeof(JSSharedArrayBufferFunctions);
    case ID_SIZEOF_BOOL: return sizeof(bool);
    case ID_SIZEOF_ENUM: return sizeof(JSCFunctionEnum);
    case ID_SIZEOF_CLASSID: return sizeof(JSClassID);
    case ID_SIZEOF_ATOM: return sizeof(JSAtom);
    case ID_TAG_FIRST: return JS_TAG_FIRST;
    case ID_TAG_OBJECT: return JS_TAG_OBJECT;
    case ID_TAG_FLOAT64: return JS_TAG_FLOAT64;
    case ID_TAG_EXCEPTION: return JS_TAG_EXCEPTION;
    case ID_TAG_SHORT_BIG_INT: return JS_TAG_SHORT_BIG_INT;
    case ID_TAG_STRING_ROPE: return JS_TAG_STRING_ROPE;
    case ID_TAG_MODULE: return JS_TAG_MODULE;
    case ID_PROP_C_W_E: return JS_PROP_C_W_E;
    case ID_PROP_THROW: return JS_PROP_THROW;
    case ID_EVAL_ASYNC: return JS_EVAL_FLAG_ASYNC;
    case ID_DEF_PROP_BOOL: return JS_DEF_PROP_BOOL;
    case ID_ABORT_ON_LEAKS: return JS_ABORT_ON_LEAKS;
    case ID_VER_MAJOR: return QJS_VERSION_MAJOR;
    case ID_VER_MINOR: return QJS_VERSION_MINOR;
    case ID_VER_PATCH: return QJS_VERSION_PATCH;
    case ID_EVAL_OPTIONS_VERSION: return JS_EVAL_OPTIONS_VERSION;
    default: return -1;
    }
}

int qjsd_abi_count(void) { return ID_COUNT; }

/* By-value JSValue passing/returning, using the C compiler's own macros. */
JSValue qjsd_abi_make_int(int v) { return JS_NewInt32(NULL, v); }
JSValue qjsd_abi_make_float(double d) { return JS_NewFloat64(NULL, d); }
JSValue qjsd_abi_make_undefined(void) { return JS_UNDEFINED; }
JSValue qjsd_abi_make_bool(int b) { return JS_NewBool(NULL, b); }
int qjsd_abi_get_tag(JSValue v) { return JS_VALUE_GET_TAG(v); }
int qjsd_abi_get_int(JSValue v) { return JS_VALUE_GET_INT(v); }
double qjsd_abi_get_float(JSValue v) { return JS_VALUE_GET_FLOAT64(v); }
JSValue qjsd_abi_echo(JSValue v) { return v; }
