module enactor.trace;

void trace(T...)(T args, string func = __FUNCTION__) {
    import std.stdio : writeln;
    if (args.length > 0) {
        debug writeln("*trace: ", func, "- ", args);
    } else {
        debug writeln("*trace: ", func);
    }
}
