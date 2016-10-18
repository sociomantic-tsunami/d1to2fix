/******************************************************************************

    Helper tool for migration from D1 to D2 which takes care of few minor
    differences that are relatively easy to automate and very annoying to
    fix manually:

    - manifest constants adaptation
    - preserving struct/union "this" as a pointer
    - making all delegates scope

    Copyright: Copyright (c) 2016 Sociomantic Labs. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

******************************************************************************/

module d1to2fix.main;

import std.stdio : File, stderr;

/**
    Aggregates configuration parsed from CLI arguments supplied to d1to2fix
    binary. Encapsulates mapping between CLI and configuration fields.
 **/
struct Config
{
    /**
        If set to true, causes converted source to be printed to
        standard output instead of filesystem
     **/
    bool printToStdout;

    /**
        If empty string, files will be converted in-place;
        otherwise output will be written to a file with this suffix
        appended to original filename
     **/
    string suffix;

    /**
        If set to true, causes d1to2fix to terminate if conversion
        of any single file fails. By default it will try to convert
        all remaining ones.

        NB: as conversion is done in parallel, early termination
        may result in broken half-converted files remaining in the
        filesystem.
     **/
    bool fatal;

    /**
        Arrays of import paths to be scanned to build initial module
        cache used later during conversion stage for resolving symbols.
     **/
    string[] importPaths;

    /**
        If not empty, contains path to file which contains list of
        file to convert (newline separated).
     **/
    string inputListFile;

    /**
        Initializes configuration, removes processed configuration
        arguments from the array.

        Params:
            args = CLI arguments, all parsed options get removed

        Returns:
            `getopt` result metadata
     **/
    auto initFromArgs ( ref string[] args )
    {
        import std.getopt;

        return getopt(
            args,
            "s|stdout", "Indicates that output needs to be printed to console",
                &this.printToStdout,
            "o|suffix", "String to append to original filename when writing" ~
                " output. If empty, convertion will be done in-place",
                &this.suffix,
            "f|fatal", "Terminate d1to2fix immediately if conversion of any" ~
                " single file fails", &this.fatal,
            "I|import", "Build symbol cache for all module under the import path",
                &this.importPaths,
            "input", "Path to file containing newline-separated file paths to convert",
                &this.inputListFile
        );
    }
}

/**
    Application entry point. Takes care of CLI interaction and all
    user-facing logic.
 **/
int main ( string[] args )
{
    // All arguments that remain after configuration parsing are
    // file names to convert

    Config config;
    auto parsed_args = config.initFromArgs(args);

    if (   parsed_args.helpWanted
        || (args.length < 2 && config.inputListFile.length == 0))
    {
        import std.getopt : defaultGetoptPrinter;
        defaultGetoptPrinter("d1to2fix [OPTIONS] [FILES]",
            parsed_args.options);
        return 1;
    }

    if (config.printToStdout && args.length > 2)
    {
        stderr.writeln("Can't use --stdout with multiple source files because" ~
            " conversion has to be done in parallel");
        return 1;
    }

    // Get file name list to convert

    import std.algorithm : splitter, filter;
    import std.array;
    import std.file : readText;

    string[] fileNames;

    if (config.inputListFile.length != 0)
    {
        fileNames = readText(config.inputListFile)
            .splitter("\n")
            .filter!(s => s.length)
            .array();
    }

    fileNames ~= args[1 .. $];

    // disable all warnings from dsymbol

    import std.experimental.logger;
    globalLogLevel = LogLevel.error;

    // Build symbol cache for parsed modules

    // For now import paths to runtime and standard library are hard-coded
    // because there is no clear place where such configuration can be placed.
    // Eventually it may be worth to find and parse `dmd.conf` file to
    // figure it out

    import d1to2fix.symbolsearch;
    import std.file : exists;

    if (exists("/usr/include/d2/dmd-transitional"))
        config.importPaths ~= "/usr/include/d2/dmd-transitional/";
    else if (exists("/usr/include/dmd/druntime/import"))
        config.importPaths ~= "/usr/include/dmd/druntime/import/";
    else if (exists("/usr/include/dlang/dmd"))
        config.importPaths ~= "/usr/include/dlang/dmd/";

    initializeModuleCache(config.importPaths);

    // Converting each file is 100% independent from others and can be done
    // in parallel with multiple threads

    import std.parallelism : parallel;

    bool success = true;

    foreach (fileName; parallel(fileNames))
    {
        import std.array : uninitializedArray;
        import std.stdio : File;

        ubyte[] inputBytes;

        {
            File input = File(fileName, "rb");
            scope(exit)
                input.close();

            if (input.size == 0)
                continue;

            inputBytes = uninitializedArray!(ubyte[])(input.size);
            input.rawRead(inputBytes);
        }

        File output;
        scope(exit)
            output.close();

        if (config.printToStdout)
        {
            import std.stdio : stdout;
            output = stdout;
        }
        else
        {
            output = File(fileName ~ config.suffix, "wb");
        }

        success &= upgradeFile(fileName, inputBytes, output);

        if (!success && config.fatal)
        {
            stderr.writeln("Fatal flag supplied, aborting immediately. May result in " ~
                "some file corruption");
            import core.stdc.stdlib;
            exit(1);
        }
    }

    return success ? 0 : 1;
}

/**
    Params:
        fileName = file input was read from, used in error reporting
        input = content of file to convert
        output = file to write result to
 **/
bool upgradeFile ( string fileName, ubyte[] input, File output )
{
    import d1to2fix.visitor;
    import d1to2fix.converter;

    import dparse.lexer;
    import dparse.parser : parseModule;

    import std.array : array;
    import std.algorithm : filter;

    LexerConfig config;
    config.fileName = fileName;
    config.stringBehavior = StringBehavior.source;

    // Uses dparse lexer to tokenize input text, token strings are stored
    // in optimized way using string cache

    StringCache cache = StringCache(StringCache.defaultBucketCount);
    auto tokens = byToken(input, config, &cache).array;

    // Filters away chars that don't have any semantical meaning to speed up
    // parsing process

    auto parsed = tokens.filter!(
        a => a != tok!"whitespace"
          && a != tok!"comment"
          && a != tok!"specialTokenSequence"
    ).array();

    // Parse token sequence and create the AST

    uint errors;

    static void report (string file, size_t line, size_t column,
        string message, bool isError)
    {
        if (isError)
            // libdparse triggers warnings for old alias syntax `alias OLD NEW`
            // to encourage switching to `alias NEW = OLD` form. But this
            // isn't supported by D1 thus only errors get printed and warnings
            // are silenced
            stderr.writefln("%s(%d:%d)[error]: %s", file, line, column, message);
    }

    import dparse.rollback_allocator;
    auto ast = parseModule(parsed, fileName, new RollbackAllocator, &report, &errors);

    if (errors)
    {
        stderr.writefln("%d parse errors encountered. Aborting upgrade of %s",
            errors, fileName);
        return false;
    }

    // Custom d1to2fix visitor class iterates resulting AST and creates
    // mappings between language constructs that need to be converted and token
    // indexes in the original lexed array

    scope visitor = new TokenMappingVisitor(parsed, fileName);
    visitor.visit(ast);
    auto token_mappings = visitor.foundTokenMappings();

    // d1to2fix.converter.convert defines how exactly source code needs to
    // be modified using all information gathered so far:

    convert(tokens, token_mappings).writeTo(output);
    return true;
}

