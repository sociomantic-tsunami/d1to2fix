module test.snippets.main;

int main()
{
    import std.file : dirEntries, SpanMode, readText, write;
    import std.process;
    import std.exception : enforce;
    import std.stdio : writefln, writeln;
    import std.algorithm : joiner, map, filter;
    import std.array;

    auto sources = dirEntries("./tests", "*.d", SpanMode.depth)
        .filter!(entry => entry.isFile)
        .map!(entry => entry.name);

    enum TMP_FILE = "./build/last/tmp/test_snippets.list";
    write(TMP_FILE, sources.join("\n"));

    // convert all snippets at once for performance
    auto cmd = "./build/last/bin/d1to2fix -o .converted -I./tests/ --input " ~ TMP_FILE;
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
