module test.snippets.main;

int main()
{
    import std.file : dirEntries, SpanMode, readText;
    import std.process;
    import std.exception : enforce;
    import std.stdio : writefln, writeln;
    import std.algorithm : joiner, map, filter;
    import std.array;

    string[] sources = dirEntries("./tests", "*.d", SpanMode.depth)
        .filter!(entry => entry.isFile)
        .map!(entry => entry.name)
        .array();

    // convert all snippets at once for performance
    auto cmd = "./build/last/bin/d1to2fix -o .converted " ~ sources.join(" ");
    auto ret = executeShell(cmd);
    enforce(ret.status == 0, cmd);

    foreach (entry; sources)
    {
        auto expected = entry ~ ".expected";
        auto converted = entry ~ ".converted";

        if (readText(converted) != readText(expected))
        {
            writefln("[%s] converted code doesn't match expected one.", entry);

            auto diff = pipeShell("diff -y " ~ converted ~ " " ~ expected);
            enforce(wait(diff.pid) == 1);
            writeln(diff.stderr.byLine().joiner("\n"));
            writeln(diff.stdout.byLine().joiner("\n"));

            return -1;
        }
    }

    return 0;
}
