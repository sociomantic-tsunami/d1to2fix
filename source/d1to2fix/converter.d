/******************************************************************************

    Defines exact mappings between D1 and D2 code and does final file output.

    Copyright: Copyright (c) 2016 Sociomantic Labs. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

******************************************************************************/

module d1to2fix.converter;

import d1to2fix.visitor;
import dparse.lexer;
import std.algorithm.searching : canFind;

/**

    Prepares data for conversion

    Doesn't actual conversion on its own but instead returns a struct instance
    with a single `writeTo` method. This is done simply to prettify the API.

    Params:
        tokens = array of tokens from initial lexing (with comments and
            whitespaces)
        token_mappings = aggregate with all mappings between AST and token
            array that will be needed for conversion

    Returns:
        converter struct

 **/
public Converter convert ( const(Token)[] tokens,
    TokenMappings token_mappings )
{
    return Converter(tokens, token_mappings);
}

/**
 * List of tokens that can be injected through `d1to2fix_inject`
 */
private static immutable allowed_tokens = [ "const", "inout", "scope" ];

private struct Converter
{
    import std.stdio : File;

    private const(Token)[] tokens;
    private TokenMappings token_mappings;

    void writeTo ( File output )
    in
    {
        assert (this.tokens.length > 0);
    }
    body
    {
        void writeToken ( in Token token )
        {
            // Tokens for special symbols used in language don't have any
            // text value and require extra step to get back to text form
            output.write(token.text is null ? str(token.type) : token.text);
        }

        foreach (index, token; this.tokens)
        {
            scope (exit)
            {
                // Getting rid of mappings for already processed tokens to
                // speed up further lookups
                this.token_mappings.value_aggregates.removeUntil(token.index);
                this.token_mappings.scope_delegates.removeUntil(token.index);
            }

            // convert all delegates into scope delegates to reduce GC allocations
            // from uncalled closures
            if (this.token_mappings.scope_delegates.contain(token.index))
                output.write("scope ");

            switch (token.type)
            {
                case tok!"const":
                    // convert all manifest constants
                    if (this.token_mappings.value_aggregates.contain(token.index))
                        // special case for struct members where usage of static
                        // immutable has proven impractical for existing
                        // projects
                        output.write("enum");
                    else
                        output.write("static immutable");
                    break;
                case tok!"this":
                    // convert all "this" mentions inside struct bodies to
                    // pointers to match D1
                    if (this.token_mappings.value_aggregates.contain(token.index))
                        output.write("(&this)");
                    else
                        writeToken(token);
                    break;
                case tok!"comment":
                    import std.regex;
                    static inject_pattern = ctRegex!("/\\* d1to2fix_inject: (.+) \\*/");
                    auto match = matchFirst(token.text, inject_pattern);
                    if (match.empty)
                        writeToken(token);
                    else
                    {
                        if (allowed_tokens.canFind(match[1]))
                            output.write(match[1]);
                        else
                            output.write("<unsupported token injection>");
                    }
                    break;
                default:
                    writeToken(token);
                    break;
            }
        }
    }
}
