struct S
{
    alias void delegate ( int ) SomeDg;
}

void foo ( S.SomeDg dg1, S.SomeDg d2 );
