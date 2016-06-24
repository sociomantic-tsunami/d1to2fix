#!/usr/bin/rdmd

int main()
{
    import std.file : dirEntries, SpanMode, readText;
    import std.process;
    import std.exception : enforce;
    import std.stdio : writefln, writeln;
    import std.algorithm : joiner;

    foreach (entry; dirEntries("./tests", "*.d", SpanMode.depth))
    {
        writefln("Testing '%s'", entry);
        auto ret = executeShell("./d1to2fix --stdout " ~ entry);
        enforce(ret.status == 0);

        auto expected = entry ~ ".expected";

        if (ret.output != readText(expected))
        {
            writefln("[%s] converted code doesn't match expected one.", entry);

            auto diff = pipeShell("diff -y - " ~ expected);
            diff.stdin().writeln(ret.output);
            diff.stdin().close();
            enforce(wait(diff.pid) == 1);
            writeln(diff.stderr.byLine().joiner("\n"));
            writeln(diff.stdout.byLine().joiner("\n"));

            return -1;
        }
    }

    writefln("All tests have passed");

    return 0;
}
