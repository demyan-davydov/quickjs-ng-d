/// Exceptions of the high-level API.
module quickjs.exception;

/// A JavaScript exception converted to a D exception.
/// Holds only plain strings (no JS handles), so it is safe to keep, copy and let the
/// D GC collect at any time.
class JSException : Exception
{
    /// JS error class name, e.g. "TypeError" (empty if a non-Error value was thrown).
    string jsName;
    /// JS `stack` property, if any.
    string jsStack;

    this(string message, string jsName = "", string jsStack = "",
        string file = __FILE__, size_t line = __LINE__) @safe pure nothrow
    {
        super(message, file, line);
        this.jsName = jsName;
        this.jsStack = jsStack;
    }
}
