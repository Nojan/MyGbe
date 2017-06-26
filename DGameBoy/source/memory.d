import numeric_alias;

struct Memory {

    u8 readU8(u16 address) const { return mem[address]; }
    void writeU8(u16 address, u8 value) { mem[address] = value; }

    u16 readU16(u16 address) const {
        const u16 low = readU8(address);
        const u16 high = readU8(cast(u16)(address+1));
        const u16 val = (high << 8) | low;
        return val; 
    }

    void writeU16(u16 address, u16 value) { 
        const u8 low = (value & 0xFF00) >> 8;
        const u8 high = (value & 0xFF);
        writeU8(address, high);
        writeU8(cast(u16)(address+1), low);
    }

    u8[0x200] mem;

    unittest
    {
        Memory m;
        {
            immutable u16 test_value = 0xBEEF;
            immutable u16 address = 0x100;
            m.writeU16(address, test_value);
            assert(test_value == m.readU16(address));
        }
    }
}