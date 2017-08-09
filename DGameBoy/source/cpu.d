import numeric_alias;

struct RegHalf { u8 low = 0; u8 high = 0; }
union Reg { 
    RegHalf half; 
    u16 val = 0; 
    
    unittest
    {
        Reg r;
        r.val = 0x0;
        assert(0x00 == r.half.high);
        assert(0x00 == r.half.low);
        r.val = 0xF5F3;
        assert(0xF5 == r.half.high);
        assert(0xF3 == r.half.low);
    }
}

struct CPU {
private:
    Reg rAF = { val : 0x01B0 };
    Reg rBC = { val : 0x0013 };
    Reg rDE = { val : 0x00D8 };
    Reg rHL = { val : 0x014D };
public:
    u16 SP = 0xFFFE;
    u16 PC = 0x100;
    i16 CycleCount = 0;
    u64 TotalCycleCount = 0;
    bool IME = true;

    @property u16 AF() const { return rAF.val; }
    @property u16 AF(u16 value) { rAF.val = value; return value; }

    @property u8 A() const { return rAF.half.high; }
    @property ref u8 A() { return rAF.half.high; }
    @property u8 A(u8 value) { rAF.half.high = value; return value; } 

    @property u8 F() const { return rAF.half.low; }
    @property u8 F(u8 value) { rAF.half.low = value; return value; } 

    @property u16 BC() const { return rBC.val; }
    @property ref u16 BC() { return rBC.val; }
    @property u16 BC(u16 value) { rBC.val = value; return value; }

    @property u8 B() const { return rBC.half.high; }
    @property ref u8 B() { return rBC.half.high; }
    @property u8 B(u8 value) { rBC.half.high = value; return value; } 

    @property u8 C() const { return rBC.half.low; }
    @property ref u8 C() { return rBC.half.low; }
    @property u8 C(u8 value) { rBC.half.low = value; return value; } 

    @property u16 DE() const { return rDE.val; }
    @property ref u16 DE() { return rDE.val; }
    @property u16 DE(u16 value) { rDE.val = value; return value; }

    @property u8 D() const { return rDE.half.high; }
    @property ref u8 D() { return rDE.half.high; }
    @property u8 D(u8 value) { rDE.half.high = value; return value; } 

    @property u8 E() const { return rDE.half.low; }
    @property ref u8 E() { return rDE.half.low; }
    @property u8 E(u8 value) { rDE.half.low = value; return value; } 

    @property u16 HL() const { return rHL.val; }
    @property ref u16 HL() { return rHL.val; }
    @property u16 HL(u16 value) { rHL.val = value; return value; }

    @property u8 H() const { return rHL.half.high; }
    @property ref u8 H() { return rHL.half.high; }
    @property u8 H(u8 value) { rHL.half.high = value; return value; } 

    @property u8 L() const { return rHL.half.low; }
    @property ref u8 L() { return rHL.half.low; }
    @property u8 L(u8 value) { rHL.half.low = value; return value; } 

    @property bool FlagZ() const { return readFlag(7); }
    @property bool FlagZ(bool value) { return writeFlag(7, value); } 

    @property bool FlagN() const { return readFlag(6); }
    @property bool FlagN(bool value) { return writeFlag(6, value); } 

    @property bool FlagH() const { return readFlag(5); }
    @property bool FlagH(bool value) { return writeFlag(5, value); } 

    @property bool FlagC() const { return readFlag(4); }
    @property bool FlagC(bool value) { return writeFlag(4, value); } 
    
    bool writeFlag(u8 n, bool value) {
        assert(n < 8);
        assert(3 < n);
        if(value)
            F = F | cast(u8)(0x1 << n);
        else
            F = F & ~(0x1 << n);
        return value;
    }

    bool readFlag(u8 n) const { assert(n < 8); return (F >> n) & 0x1; }

    unittest
    {
        // test init
        {
            CPU cpu;
            assert(0x01B0 == cpu.AF);
            assert(0x0013 == cpu.BC);
            assert(0x00D8 == cpu.DE);
            assert(0x014D == cpu.HL);
        }
        // test Flag
        {
            CPU cpu;
            assert(0xB0 == cpu.F);
            cpu.FlagZ = true;
            cpu.FlagN = true;
            cpu.FlagH = true;
            cpu.FlagC = true;
            assert(0xF0 == cpu.F);
        }
        // test register
        {
            CPU cpu;
            cpu.AF = 0xFEFC;
            assert(0xFE == cpu.A);
            assert(0xFC == cpu.F);
            cpu.BC = 0xFEFC;
            assert(0xFE == cpu.B);
            assert(0xFC == cpu.C);
            cpu.DE = 0xFEFC;
            assert(0xFE == cpu.D);
            assert(0xFC == cpu.E);
            cpu.HL = 0xFEFC;
            assert(0xFE == cpu.H);
            assert(0xFC == cpu.L);
        }
    }
}