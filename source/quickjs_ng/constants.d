// Based on quickjs.h of QuickJS-NG (https://github.com/quickjs-ng/quickjs, v0.18.0).
// Copyright (c) 2017-2026 Fabrice Bellard, Charlie Gordon, Ben Noordhuis, Saul Ibarra Corretge
// and contributors. Distributed under the MIT License (see ../../LICENSE).
/// Constants from quickjs.h (QuickJS-NG, version pinned in VENDOR.md).
module quickjs_ng.constants;

enum QJS_VERSION_MAJOR = 0;
enum QJS_VERSION_MINOR = 18;
enum QJS_VERSION_PATCH = 0;
enum QJS_VERSION_SUFFIX = "";

// JSValue tags (64-bit, non-NaN-boxing)
enum : int
{
    JS_TAG_FIRST = -9,
    JS_TAG_BIG_INT = -9,
    JS_TAG_SYMBOL = -8,
    JS_TAG_STRING = -7,
    JS_TAG_STRING_ROPE = -6,
    JS_TAG_MODULE = -3,
    JS_TAG_FUNCTION_BYTECODE = -2,
    JS_TAG_OBJECT = -1,

    JS_TAG_INT = 0,
    JS_TAG_BOOL = 1,
    JS_TAG_NULL = 2,
    JS_TAG_UNDEFINED = 3,
    JS_TAG_UNINITIALIZED = 4,
    JS_TAG_CATCH_OFFSET = 5,
    JS_TAG_EXCEPTION = 6,
    JS_TAG_SHORT_BIG_INT = 7,
    JS_TAG_FLOAT64 = 8,
}

// property flags
enum : int
{
    JS_PROP_CONFIGURABLE = 1 << 0,
    JS_PROP_WRITABLE = 1 << 1,
    JS_PROP_ENUMERABLE = 1 << 2,
    JS_PROP_C_W_E = JS_PROP_CONFIGURABLE | JS_PROP_WRITABLE | JS_PROP_ENUMERABLE,
    JS_PROP_LENGTH = 1 << 3,
    JS_PROP_TMASK = 3 << 4,
    JS_PROP_NORMAL = 0 << 4,
    JS_PROP_GETSET = 1 << 4,
    JS_PROP_VARREF = 2 << 4,
    JS_PROP_AUTOINIT = 3 << 4,

    JS_PROP_HAS_SHIFT = 8,
    JS_PROP_HAS_CONFIGURABLE = 1 << 8,
    JS_PROP_HAS_WRITABLE = 1 << 9,
    JS_PROP_HAS_ENUMERABLE = 1 << 10,
    JS_PROP_HAS_GET = 1 << 11,
    JS_PROP_HAS_SET = 1 << 12,
    JS_PROP_HAS_VALUE = 1 << 13,
    JS_PROP_THROW = 1 << 14,
    JS_PROP_THROW_STRICT = 1 << 15,
    JS_PROP_NO_ADD = 1 << 16,
    JS_PROP_NO_EXOTIC = 1 << 17,
    JS_PROP_DEFINE_PROPERTY = 1 << 18,
    JS_PROP_REFLECT_DEFINE_PROPERTY = 1 << 19,
}

enum JS_DEFAULT_STACK_SIZE = 1024 * 1024;

// JS_Eval flags
enum : int
{
    JS_EVAL_TYPE_GLOBAL = 0 << 0,
    JS_EVAL_TYPE_MODULE = 1 << 0,
    JS_EVAL_TYPE_DIRECT = 2 << 0,
    JS_EVAL_TYPE_INDIRECT = 3 << 0,
    JS_EVAL_TYPE_MASK = 3 << 0,
    JS_EVAL_FLAG_STRICT = 1 << 3,
    JS_EVAL_FLAG_UNUSED = 1 << 4,
    JS_EVAL_FLAG_COMPILE_ONLY = 1 << 5,
    JS_EVAL_FLAG_BACKTRACE_BARRIER = 1 << 6,
    JS_EVAL_FLAG_ASYNC = 1 << 7,
}
enum JS_EVAL_OPTIONS_VERSION = 1;

// dump flags
enum : ulong
{
    JS_DUMP_BYTECODE_FINAL = 0x01,
    JS_DUMP_BYTECODE_PASS2 = 0x02,
    JS_DUMP_BYTECODE_PASS1 = 0x04,
    JS_DUMP_BYTECODE_HEX = 0x10,
    JS_DUMP_BYTECODE_PC2LINE = 0x20,
    JS_DUMP_BYTECODE_STACK = 0x40,
    JS_DUMP_BYTECODE_STEP = 0x80,
    JS_DUMP_READ_OBJECT = 0x100,
    JS_DUMP_FREE = 0x200,
    JS_DUMP_GC = 0x400,
    JS_DUMP_GC_FREE = 0x800,
    JS_DUMP_MODULE_RESOLVE = 0x1000,
    JS_DUMP_PROMISE = 0x2000,
    JS_DUMP_LEAKS = 0x4000,
    JS_DUMP_ATOM_LEAKS = 0x8000,
    JS_DUMP_MEM = 0x10000,
    JS_DUMP_OBJECTS = 0x20000,
    JS_DUMP_ATOMS = 0x40000,
    JS_DUMP_SHAPES = 0x80000,
    JS_ABORT_ON_LEAKS = 0x10C000,
}

enum JS_CALL_FLAG_CONSTRUCTOR = 1 << 0;
enum JS_INVALID_CLASS_ID = 0;

// JS_GetOwnPropertyNames flags
enum : int
{
    JS_GPN_STRING_MASK = 1 << 0,
    JS_GPN_SYMBOL_MASK = 1 << 1,
    JS_GPN_PRIVATE_MASK = 1 << 2,
    JS_GPN_ENUM_ONLY = 1 << 4,
    JS_GPN_SET_ENUM = 1 << 5,
}

// JS_WriteObject / JS_ReadObject flags
enum : int
{
    JS_WRITE_OBJ_BYTECODE = 1 << 0,
    JS_WRITE_OBJ_BSWAP = 0,
    JS_WRITE_OBJ_SAB = 1 << 2,
    JS_WRITE_OBJ_REFERENCE = 1 << 3,
    JS_WRITE_OBJ_STRIP_SOURCE = 1 << 4,
    JS_WRITE_OBJ_STRIP_DEBUG = 1 << 5,

    JS_READ_OBJ_BYTECODE = 1 << 0,
    JS_READ_OBJ_ROM_DATA = 0,
    JS_READ_OBJ_SAB = 1 << 2,
    JS_READ_OBJ_REFERENCE = 1 << 3,
}

// JSCFunctionListEntry.def_type
enum : int
{
    JS_DEF_CFUNC = 0,
    JS_DEF_CGETSET = 1,
    JS_DEF_CGETSET_MAGIC = 2,
    JS_DEF_PROP_STRING = 3,
    JS_DEF_PROP_INT32 = 4,
    JS_DEF_PROP_INT64 = 5,
    JS_DEF_PROP_DOUBLE = 6,
    JS_DEF_PROP_UNDEFINED = 7,
    JS_DEF_OBJECT = 8,
    JS_DEF_ALIAS = 9,
    JS_DEF_PROP_SYMBOL = 10,
    JS_DEF_PROP_BOOL = 11,
}
