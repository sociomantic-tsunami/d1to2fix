// define some symbols for dsymbol semantic analysis to work
template Const ( T ) { alias void T; }

// Basic type
void foo(int delegate() dg) {}

// Leading dot + identifier
void foo1(.Foo delegate() dg) {}
// Fully qualified identifier
void foo2(Weird.Identity!(int) delegate(int, void) dg) {}

// TemplateInstance
void foo3(Identity!(int) delegate() dg) {}
// FQ TI
void foo4(Something.Identity!(int) delegate() dg) {}
// leading dot, FQ, TI
void foo5(.Something.Identity!(int) delegate(int, void) dg) {}

/// Nested are *not* processed
void foo6(.Something.Identity!(int) delegate(.Something.Identity!(void*) delegate()) dg) {}

/// Aliases are *not* processed (it has no effect at functions using them)
public alias size_t delegate (Const!(void)[]) Sink;
public alias size_t delegate (void[]) MutableSink;

public class Foobar
{
    this (void delegate () dg) {}
}

public void write (Sink sink, in char[] data) {}
