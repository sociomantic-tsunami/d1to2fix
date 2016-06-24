const x = 42;

void main (in char[] args)
{
    const y = 43;
}

struct S
{
    // test that const is converted to enum within struct
    const z = 44;
}
