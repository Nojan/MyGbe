import numeric_alias;

struct Memory {

    pure nothrow @nogc
    u8 readU8(u16 address) const 
    { 
        u8 value = mem[address];
        if(P1 == address)
        {
            if( !(value & 0x20) )
                value = 0xDF;
            else if( !(value & 0x10) )
                value = 0xEF;
            else if( !(value & 0x30) )
                value = 0xFF;
            else
                value = 0;
        }
        return value; 
    }

    pure nothrow @nogc
    void writeU8(u16 address, u8 value)
    { 
        if(LY == address)
            value = 0;
        if(DMA == address)
        {        
            dmaTransfert(value);
            return;
        }
        mem[address] = value; 
    }

    pure nothrow @nogc
    u16 readU16(u16 address) const {
        const u16 low = readU8(address);
        const u16 high = readU8(cast(u16)(address+1));
        const u16 val = (high << 8) | low;
        return val; 
    }

    pure nothrow @nogc
    void writeU16(u16 address, u16 value) { 
        const u8 low = (value & 0xFF00) >> 8;
        const u8 high = (value & 0xFF);
        writeU8(address, high);
        writeU8(cast(u16)(address+1), low);
    }

    u8[] Cart() {
        return mem[0..0x8000];
    }

    enum : u16 {
        VBLANK = 0x0040,
        LCDSTAT = 0x0048,
        TIMER = 0x0050,
        SERIAL = 0x0058,
        JOYPAD = 0x0060,
        P1 = 0xFF00,
        TIMA = 0xFF05,
        TMA = 0xFF06,
        TAC = 0xFF07,
        IF = 0xFF0F,
        NR10 = 0xFF10,
        NR11 = 0xFF11,
        NR12 = 0xFF12,
        NR14 = 0xFF14,
        NR21 = 0xFF16,
        NR22 = 0xFF17,
        NR24 = 0xFF19,
        NR30 = 0xFF1A,
        NR31 = 0xFF1B,
        NR32 = 0xFF1C,
        NR33 = 0xFF1E,
        NR41 = 0xFF20,
        NR42 = 0xFF21,
        NR43 = 0xFF22,
        NR44 = 0xFF23,
        NR50 = 0xFF24,
        NR51 = 0xFF25,
        NR52 = 0xFF26,
        LCDC = 0xFF40,
        STAT = 0xFF41,
        SCY = 0xFF42,
        SCX = 0xFF43,
        LY = 0xFF44,
        LYC = 0xFF45,
        DMA = 0xFF46,
        BGP = 0xFF47,
        OBP0 = 0xFF48,
        OBP1 = 0xFF49,
        WY = 0xFF4A,
        WX = 0xFF4B,
        IE = 0xFFFF,
    }

    void Reset() {
        mem[P1] = 0xEF; 
        mem[TIMA] = 0x00; 
        mem[TMA] = 0x00; 
        mem[TAC] = 0x00; 
        mem[IF] = 0x00; 
        mem[NR10] = 0x80; 
        mem[NR11] = 0x00; 
        mem[NR12] = 0xF3; 
        mem[NR14] = 0xBF; 
        mem[NR21] = 0x3F; 
        mem[NR22] = 0x00; 
        mem[NR24] = 0xBF; 
        mem[NR30] = 0x7F; 
        mem[NR31] = 0xFF; 
        mem[NR32] = 0x9F;
        mem[NR33] = 0xBF;
        mem[NR41] = 0xFF;
        mem[NR42] = 0x00;
        mem[NR43] = 0x00;
        mem[NR44] = 0xBF;
        mem[NR50] = 0x77;
        mem[NR51] = 0xF3;
        mem[NR52] = 0xF1;
        mem[LCDC] = 0x91;
        mem[STAT] = 0x80;
        mem[SCY] = 0x00; 
        mem[SCX] = 0x00;
        mem[LY] = 0x00; 
        mem[LYC] = 0x00; 
        mem[BGP] = 0xFC; 
        mem[OBP0] = 0xFF;
        mem[OBP1] = 0xFF;
        mem[WY] = 0x00; 
        mem[WX] = 0x00; 
        mem[IE] = 0x00; 
    }

    u8[0x10000] mem;

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

private:
    pure nothrow @nogc
    void dmaTransfert(u8 value)
    {
        const u16 address = value << 0x8;
        for (u16 i = 0 ; i < 0xA0; i++)
        {
            const u8 val = readU8(cast(u16)(address+i));
            writeU8(cast(u16)(0xFE00+i), val);
        }
    }
}