import numeric_alias;

pure nothrow @nogc
u8 set(u8 bit, u8 idx) 
{
    assert(idx < 8);
    bit |= 0x1 << idx;
    return bit;
}

pure nothrow @nogc
u8 reset(u8 bit, u8 idx) 
{
    assert(idx < 8);
    bit &= ~(0x1 << idx);
    return bit;
}

pure nothrow @nogc
bool test(u8 bit, u8 idx) 
{
    assert(idx < 8);
    return (bit & (0x1 << idx)) != 0;
}

pure nothrow @nogc
u8 val(u8 bit, u8 idx) 
{
    assert(idx < 8);
    return !!(bit & (0x1 << idx));
}