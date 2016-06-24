struct S
{
    alias typeof(*this) This;

    void foo ()
    {
        this.foo();
    }
}

struct XXX
{
    class ZZZ
    {
        struct YYY
        {
            typeof(this) next;
        }

        class AAA
        {
            AAA foo ( )
            {
                return this;
            }
        }
    }
}

class C
{
    this ( )
    {
    }

    struct CS
    {
        alias typeof(*this) This;
    }

    union CU
    {
        int x;

        CU* foo ()
        {
            return this;
        }
    }
}
