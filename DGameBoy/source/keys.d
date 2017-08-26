import numeric_alias;
import bitop;

struct Keys {
    bool a = true;
    bool b = true;
    bool select = true;
    bool start = true;
    bool up = true;
    bool down = true;
    bool left = true;
    bool right = true;

    pure nothrow @nogc
    u8 GetState(const u8 ff00) const
    {
        u8 value = ff00;
        if(bitop.test(ff00,4))
        {
            if(a)
                value = bitop.set(value, 0);
            else
                value = bitop.reset(value, 0);
            if(b)
                value = bitop.set(value, 1);
            else
                value = bitop.reset(value, 1);
            if(select)
                value = bitop.set(value, 2);
            else
                value = bitop.reset(value, 2);
            if(start)
                value = bitop.set(value, 3);
            else
                value = bitop.reset(value, 3);
        }
        else if(bitop.test(ff00,5)) // dir
        {
            if(right)
                value = bitop.set(value, 0);
            else
                value = bitop.reset(value, 0);
            if(left)
                value = bitop.set(value, 1);
            else
                value = bitop.reset(value, 1);
            if(up)
                value = bitop.set(value, 2);
            else
                value = bitop.reset(value, 2);
            if(down)
                value = bitop.set(value, 3);
            else
                value = bitop.reset(value, 3);
        }
        value |= 0xF0;
        return value;
    }
}

