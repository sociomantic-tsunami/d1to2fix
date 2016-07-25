module d1to2fix.symbolsearch;

import dsymbol.modulecache;
import dsymbol.symbol;

private struct DelegateCache
{
    immutable DSymbol*[string] cache;

    const(DSymbol)* search(string symbolName) immutable
    {
        if (auto sym = symbolName in this.cache)
            return *sym;
        else
            return null;
    }
}

private shared immutable(DelegateCache)* delegate_cache;

/**
    NB: must be called in main thread before any file conversion workers
    start to avoid any race conditions
 */
public void initializeModuleCache(string[] paths)
{
    import std.exception;
    enforce(delegate_cache is null);

    auto module_cache = new ModuleCache(new ASTAllocator);
    module_cache.addImportPaths(paths);

    const(DSymbol)*[string] delegates;

    void collectNames (const(DSymbol*)[] symbols)
    {
        foreach (symbol; symbols)
        {
            if (   symbol.kind == CompletionKind.aliasName
                && symbol.type !is null
                && symbol.type.name == "function")
            {
                delegates[symbol.name] = symbol;
            }

            // Recursing into aggregates causes stack overflow, probably
            // a smarter iteration algorithm is needed to do it. Ignoring
            // them for now.
            if (   symbol.kind == CompletionKind.moduleName
                || symbol.kind == CompletionKind.packageName)
             // || symbol.kind == CompletionKind.structName
             // || symbol.kind == CompletionKind.interfaceName
             // || symbol.kind == CompletionKind.className)
            {
                collectNames((*symbol)[]);
            }
        }
    }

    import std.array;
    import std.algorithm;
    collectNames(module_cache.getAllSymbols().map!(entry => entry.symbol).array());

    delegate_cache = new shared DelegateCache(cast(immutable) delegates);
}

public const(DSymbol)* delegateAliasSearch(string symbolName)
{
    return delegate_cache.search(symbolName);
}
