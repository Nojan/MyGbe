// http://blog.rekawek.eu/2017/02/09/coffee-gb/
// https://github.com/retrio/gb-test-roms
// My Own Gameboy Emulator
import opcode;
import memory;
import numeric_alias;
import ppu;
import cpu;
import bitop;

struct Emu {
public:
    void Reset()
    {
        mem.Reset();
    }

    void SetRenderDelegate(void delegate(const u8[]) render)
    {
        ppu.SetRenderDelegate(render);
    }

version(TileWindow)
{
    void SetTileRenderDelegate(void delegate(const u8[]) render)
    {
        ppu.SetTileRenderDelegate(render);
    }
}
version(BGWindow)
{
    void SetBGRenderDelegate(void delegate(const u8[]) render)
    {
        ppu.SetBGRenderDelegate(render);
    }
}
    
    void Frame() 
    {
        CpuStep();
        //Interrupt();
        ppu.Step(cpu.CycleCount, mem);
        cpu.CycleCount = 0;
        Interrupt();
    }

    void CpuStep() {
        const u8 opcode = mem.readU8(cpu.PC);
        cpu.PC++;
        immutable instruction ins = instruction_table[opcode];
        u16 operand;
        if(1 == ins.length) {
            operand = mem.readU8(cpu.PC);
        } else if(2 == ins.length) {
            operand = mem.readU16(cpu.PC);
        }
        CpuExec(opcode, operand, ins);
    }

    version(LogFileCompare)
    {
        import std.stdio;
        File log_file;
    }

    void CpuExec(const u8 opcode, const u16 operand, immutable instruction ins) {
        if(true)
        {
            import crc;

            import std.stdio;
            import std.format;
            import std.string;
            const u16 PC = cast(u16)(cpu.PC - 1);
            string registers_line;
            string state_line;
            string crc_line;
            registers_line ~= format!"ROM0:%04X %02X "(PC, opcode);
            if(0 == ins.length)
                registers_line ~= "      ";
            else if(1 == ins.length)
                registers_line ~= format!"%02X    "(cast(u8)operand);
            else
                registers_line ~= format!"%02X %02X "(cast(u8)operand, cast(u8)(operand >> 8));
            registers_line ~= format!"Registers: AF%04X BC%04X DE%04X HL%04X SP%04X"(cpu.AF, cpu.BC, cpu.DE, cpu.HL, cpu.SP);
            writeln(registers_line);
            state_line = format!"State: cycle%04X scan%02X lcdc%02X stat%02X ly%02X ie%02X if%02X"(cpu.TotalCycleCount, ppu.scanLineCounter, mem.readU8(mem.LCDC), mem.readU8(mem.STAT), mem.readU8(mem.LY), mem.readU8(mem.IE), mem.readU8(mem.IF));
            writeln(state_line);
            crc_line = format!"vram: %x"(crc32(mem.VRAM()));
            writeln(crc_line);
            version(LogFileCompare)
            {
                
                
                import std.stdio;
                import std.algorithm;
                if( !log_file.isOpen() )
                    log_file = File("cinoop_tetris.log", "r");
                
                string line;

                void CompareToReference(const ref string line, const ref string reference)
                {
                    if(0 == cmp(line, reference))
                    return;
                    writeln("Mismatch:");
                    writeln(line);
                    writeln(reference);
                    assert(false);
                }

                line = chop(log_file.readln()); // Read Register
                CompareToReference(registers_line, line);
                line = chop(log_file.readln()); // Read State
                CompareToReference(state_line, line);
                line = chop(log_file.readln()); // Read CRC
                CompareToReference(crc_line, line);
            }
        }
        if(0x466A4 == cpu.TotalCycleCount)
        {
            import std.stdio;
            writeln("HALT");
        }
        cpu.PC += ins.length;
        cpu.CycleCount += ins.cycle;
        cpu.TotalCycleCount += ins.cycle;

        string GenSwitch(string opcode, string operand)
        {
            import std.format;
            string gen = "switch(" ~ opcode ~ ") {";
            foreach(idx; 0..255) {
                immutable string idx_str = format!"%02X"(idx);
                gen ~= "case 0x" ~ idx_str ~ ":";
                gen ~= "opcode_" ~ idx_str ~ "(" ~ operand ~ ");";
                gen ~= "break;";
            }
            gen ~= "default: assert(false);";
            gen ~= "}";
            return gen;
        }

        mixin(GenSwitch("opcode", "operand"));
    }

    u8[] MemoryCart() {
        return mem.Cart();
    }
    void Interrupt() {
        if(!cpu.IME)
            return;
        u8 flag = mem.readU8(mem.IF);
        immutable u8 enable = mem.readU8(mem.IE);
        immutable u8 fire = enable & flag;
        if(0 == fire)
            return;
        
        enum : u8 {
            I_VBLANK = 1<<0,
            I_LCDC   = 1<<1,
            I_TIMER  = 1<<2,
            I_SERIAL = 1<<3,
            I_JOY    = 1<<4,
        }

        if(fire & I_VBLANK) {
            flag &= ~I_VBLANK;
            jumpInterrupt(mem.VBLANK);
        }

        if(fire & I_LCDC) {
            flag &= ~I_LCDC;
            jumpInterrupt(mem.LCDSTAT);
        }

        if(fire & I_TIMER) {
            flag &= ~I_TIMER;
            jumpInterrupt(mem.TIMER);
        }

        if(fire & I_SERIAL) {
            flag &= ~I_SERIAL;
            jumpInterrupt(mem.SERIAL);
        }

        if(fire & I_JOY) {
            flag &= ~I_JOY;
            jumpInterrupt(mem.JOYPAD);
        }

        mem.writeU8(mem.IF, flag);
    }

    void jumpInterrupt(const u16 address) {
        cpu.IME = 0;
        extra_cycle(12);
        opcode_CD(address);
        //immutable u8 jump_opcode = 0xCD;
        //immutable instruction = instruction_table[jump_opcode];
        //CpuExec(jump_opcode, address, instruction);
    }

private:
    // prefix CB
    void opcode_CB(const u16 operand) { 
        const u8 cb_opcode = cast(u8)(0xFF & operand);
        immutable instruction ins = cb_instruction_table[cb_opcode];
        cpu.PC += ins.length;
        cpu.CycleCount += ins.cycle;
        cpu.TotalCycleCount += ins.cycle;

        string GenSwitch(string opcode, string operand)
        {
            import std.format;
            string gen = "switch(" ~ opcode ~ ") {";
            foreach(idx; 0..255) {
                immutable string idx_str = format!"%02X"(idx);
                gen ~= "case 0x" ~ idx_str ~ ":";
                gen ~= "opcode_cb_" ~ idx_str ~ "(" ~ operand ~ ");";
                gen ~= "break;";
            }
            gen ~= "default: assert(false);";
            gen ~= "}";
            return gen;
        }

        mixin(GenSwitch("cb_opcode", "operand"));
    }

    void extra_cycle(const u8 cycle) {
        cpu.CycleCount += cycle;
        cpu.TotalCycleCount += cycle;
    }

    // 8 bit load
    // LD nn,n
    void opcode_06(const u16 operand) {
	    cpu.B = cast(u8)operand;
    }
    void opcode_0E(const u16 operand) {
	    cpu.C = cast(u8)operand;
    }
    void opcode_16(const u16 operand) {
	    cpu.D = cast(u8)operand;
    }
    void opcode_1E(const u16 operand) {
	    cpu.E = cast(u8)operand;
    }
    void opcode_26(const u16 operand) {
	    cpu.H = cast(u8)operand;
    }
    void opcode_2E(const u16 operand) {
	    cpu.L = cast(u8)operand;
    }
    // LD r1,r2
    void opcode_7F(const u16 operand) {
        cpu.A = cpu.A;
    }
    void opcode_78(const u16 operand) {
        cpu.A = cpu.B;
    }
    void opcode_79(const u16 operand) {
        cpu.A = cpu.C;
    }
    void opcode_7A(const u16 operand) {
        cpu.A = cpu.D;
    }
    void opcode_7B(const u16 operand) {
        cpu.A = cpu.E;
    }
    void opcode_7C(const u16 operand) {
        cpu.A = cpu.H;
    }
    void opcode_7D(const u16 operand) {
        cpu.A = cpu.L;
    }
    void opcode_7E(const u16 operand) {
        cpu.A = mem.readU8(cpu.HL);
    }
    void opcode_40(const u16 operand) {
        cpu.B = cpu.B;
    }
    void opcode_41(const u16 operand) {
        cpu.B = cpu.C;
    }
    void opcode_42(const u16 operand) {
        cpu.B = cpu.D;
    }
    void opcode_43(const u16 operand) {
        cpu.B = cpu.E;
    }
    void opcode_44(const u16 operand) {
        cpu.B = cpu.H;
    }
    void opcode_45(const u16 operand) {
        cpu.B = cpu.L;
    }
    void opcode_46(const u16 operand) {
        cpu.B = mem.readU8(cpu.HL);
    }
    void opcode_48(const u16 operand) {
        cpu.C = cpu.B;
    }
    void opcode_49(const u16 operand) {
        cpu.C = cpu.C;
    }
    void opcode_4A(const u16 operand) {
        cpu.C = cpu.D;
    }
    void opcode_4B(const u16 operand) {
        cpu.C = cpu.E;
    }
    void opcode_4C(const u16 operand) {
        cpu.C = cpu.H;
    }
    void opcode_4D(const u16 operand) {
        cpu.C = cpu.L;
    }
    void opcode_4E(const u16 operand) {
        cpu.C = mem.readU8(cpu.HL);
    }
    void opcode_50(const u16 operand) {
        cpu.D = cpu.B;
    }
    void opcode_51(const u16 operand) {
        cpu.D = cpu.C;
    }
    void opcode_52(const u16 operand) {
        cpu.D = cpu.D;
    }
    void opcode_53(const u16 operand) {
        cpu.D = cpu.E;
    }
    void opcode_54(const u16 operand) {
        cpu.D = cpu.H;
    }
    void opcode_55(const u16 operand) {
        cpu.D = cpu.L;
    }
    void opcode_56(const u16 operand) {
        cpu.D = mem.readU8(cpu.HL);
    }
    void opcode_58(const u16 operand) {
        cpu.E = cpu.B;
    }
    void opcode_59(const u16 operand) {
        cpu.E = cpu.C;
    }
    void opcode_5A(const u16 operand) {
        cpu.E = cpu.D;
    }
    void opcode_5B(const u16 operand) {
        cpu.E = cpu.E;
    }
    void opcode_5C(const u16 operand) {
        cpu.E = cpu.H;
    }
    void opcode_5D(const u16 operand) {
        cpu.E = cpu.L;
    }
    void opcode_5E(const u16 operand) {
        cpu.E = mem.readU8(cpu.HL);
    }
    void opcode_60(const u16 operand) {
        cpu.H = cpu.B;
    }
    void opcode_61(const u16 operand) {
        cpu.H = cpu.C;
    }
    void opcode_62(const u16 operand) {
        cpu.H = cpu.D;
    }
    void opcode_63(const u16 operand) {
        cpu.H = cpu.E;
    }
    void opcode_64(const u16 operand) {
        cpu.H = cpu.H;
    }
    void opcode_65(const u16 operand) {
        cpu.H = cpu.L;
    }
    void opcode_66(const u16 operand) {
        cpu.H = mem.readU8(cpu.HL);
    }
    void opcode_68(const u16 operand) {
        cpu.L = cpu.B;
    }
    void opcode_69(const u16 operand) {
        cpu.L = cpu.C;
    }
    void opcode_6A(const u16 operand) {
        cpu.L = cpu.D;
    }
    void opcode_6B(const u16 operand) {
        cpu.L = cpu.E;
    }
    void opcode_6C(const u16 operand) {
        cpu.L = cpu.H;
    }
    void opcode_6D(const u16 operand) {
        cpu.L = cpu.L;
    }
    void opcode_6E(const u16 operand) {
        cpu.L = mem.readU8(cpu.HL);
    }
    void opcode_70(const u16 operand) {
        mem.writeU8(cpu.HL, cpu.B);
    }
    void opcode_71(const u16 operand) {
        mem.writeU8(cpu.HL, cpu.C);
    }
    void opcode_72(const u16 operand) {
        mem.writeU8(cpu.HL, cpu.D);
    }
    void opcode_73(const u16 operand) {
        mem.writeU8(cpu.HL, cpu.E);
    }
    void opcode_74(const u16 operand) {
        mem.writeU8(cpu.HL, cpu.H);
    }
    void opcode_75(const u16 operand) {
        mem.writeU8(cpu.HL, cpu.L);
    }
    void opcode_36(const u16 operand) {
        mem.writeU8(cpu.HL, cast(u8)(operand & 0xff));
    }
    // LD A,n
    void opcode_0A(const u16 operand) {
        cpu.A = mem.readU8(cpu.BC);
    }
    void opcode_1A(const u16 operand) {
        cpu.A = mem.readU8(cpu.DE);
    }
    void opcode_FA(const u16 operand) {
        cpu.A =  mem.readU8(operand);
    }
    void opcode_3E(const u16 operand) {
        cpu.A = cast(u8)operand;
    }
    // LD n,A
    void opcode_47(const u16 operand) {
        cpu.B = cpu.A;
    }
    void opcode_4F(const u16 operand) {
        cpu.C = cpu.A;
    }
    void opcode_57(const u16 operand) {
        cpu.D = cpu.A;
    }
    void opcode_5F(const u16 operand) {
        cpu.E = cpu.A;
    }
    void opcode_67(const u16 operand) {
        cpu.H = cpu.A;
    }
    void opcode_6F(const u16 operand) {
        cpu.L = cpu.A;
    }
    void opcode_02(const u16 operand) {
        mem.writeU8(cpu.BC, cpu.A);
    }
    void opcode_12(const u16 operand) {
        mem.writeU8(cpu.DE, cpu.A);
    }
    void opcode_77(const u16 operand) {
        mem.writeU8(cpu.HL, cpu.A);
    }
    void opcode_EA(const u16 operand) {
        mem.writeU8(operand, cpu.A);
    }
    // LD A,C
    void opcode_F2(const u16 operand) {
        cpu.A = mem.readU8(0xFF00 + cpu.C);
    }
    // LD C,A
    void opcode_E2(const u16 operand) {
        mem.writeU8(0xFF00 + cpu.C, cpu.A);
    }
    // LDD A, HL
    void opcode_3A(const u16 operand) {
        cpu.A = mem.readU8(cpu.HL);
        cpu.HL--;
    }
    // LDD HL, A
    void opcode_32(const u16 operand) {
        mem.writeU8(cpu.HL, cpu.A);
        cpu.HL--;
    }
    // LDI A, HL
    void opcode_2A(const u16 operand) {
        cpu.A = mem.readU8(cpu.HL);
        cpu.HL++;
    }
    // LDD HL, A
    void opcode_22(const u16 operand) {
        mem.writeU8(cpu.HL, cpu.A);
        cpu.HL++;
    }
    // LDH n, A
    void opcode_E0(const u16 operand) {
        immutable u16 address = cast(u16)(0xFF00 + operand);
        mem.writeU8(address, cpu.A);
    }
    // LDH n, A
    void opcode_F0(const u16 operand) {
        immutable u16 address = cast(u16)(0xFF00 + operand);
        cpu.A = mem.readU8(address);
    }
    // 16 bit load
    // LD n,nn
    void opcode_01(const u16 operand) {
	    cpu.BC = operand;
    }
    void opcode_11(const u16 operand) {
	    cpu.DE = operand;
    }
    void opcode_21(const u16 operand) {
	    cpu.HL = operand;
    }
    void opcode_31(const u16 operand) {
	    cpu.SP = operand;
    }
    // LD SP,HL
    void opcode_F9(const u16 operand) {
	    cpu.SP = cpu.HL;
    }
    // LDHL SP,n
    void opcode_F8(const u16 operand) {
	    immutable i8 op = cast(i8)(0x00FF & operand);
        int result = cpu.SP + op;
        if(result & 0xFFFF0000)
            cpu.FlagC = 1;
        else
            cpu.FlagC = 0;
        if(((cpu.SP & 0x0F) + (operand & 0x0F)) > 0x0F) 
            cpu.FlagH = 1;
        else 
            cpu.FlagH = 0;
        cpu.FlagZ = 0;
        cpu.FlagN = 0;
        cpu.HL = cast(u16)(0xFFFF & result);
    }
    // LD (nn),SP
    void opcode_08(const u16 operand) {
        mem.writeU16(operand, cpu.SP);
    }
    // PUSH nn
    void opcode_F5(const u16 operand) {
        cpu.SP -= 2;
        mem.writeU16(cpu.SP, cpu.AF);
    }
    void opcode_C5(const u16 operand) {
        cpu.SP -= 2;
        mem.writeU16(cpu.SP, cpu.BC);
    }
    void opcode_D5(const u16 operand) {
        cpu.SP -= 2;
        mem.writeU16(cpu.SP, cpu.DE);
    }
    void opcode_E5(const u16 operand) {
        cpu.SP -= 2;
        mem.writeU16(cpu.SP, cpu.HL);
    }
    // POP nn
    void opcode_F1(const u16 operand) {
        cpu.AF = mem.readU16(cpu.SP);
        cpu.SP += 2;
    }
    void opcode_C1(const u16 operand) {
        cpu.BC = mem.readU16(cpu.SP);
        cpu.SP += 2;
    }
    void opcode_D1(const u16 operand) {
        cpu.DE = mem.readU16(cpu.SP);
        cpu.SP += 2;
    }
    void opcode_E1(const u16 operand) {
        cpu.HL = mem.readU16(cpu.SP);
        cpu.SP += 2;
    }
    // 8-Bit ALU
    void addu8(ref u8 destination, u8 value) {
        u16 result = destination + value;
	
	    if(result & 0xFF00) 
            cpu.FlagC = 1;
	    else 
            cpu.FlagC = 0;
	
	    destination = cast(u8)(result & 0xFF);
	
	    if(0 != destination) 
            cpu.FlagZ = 0;
	    else 
            cpu.FlagZ = 1;
	
	    if(((destination & 0x0F) + (value & 0x0F)) > 0x0F) 
            cpu.FlagH = 1;
	    else 
            cpu.FlagH = 0;
	
        cpu.FlagN = 0;
    }
    void addcu8(ref u8 destination, u8 value) {
        addu8(destination, cast(u8)(value + cpu.FlagC));
    }
    void subu8(ref u8 destination, u8 value) {
        cpu.FlagN = 1;
	
	    if(value > destination) 
            cpu.FlagC = 1;
	    else 
            cpu.FlagC = 0;
	
	    if((value & 0x0F) > (destination & 0x0F)) 
            cpu.FlagH = 1;
	    else 
            cpu.FlagH = 0;
	
	    destination -= value;
	
	    if(0 != destination) 
            cpu.FlagZ = 0;
        else 
            cpu.FlagZ = 1;
    }
    void subcu8(ref u8 destination, u8 value) {
        subu8(destination, cast(u8)(value + cpu.FlagC));
    }
    void and(ref u8 destination, u8 value) {
        destination = destination & value;
        if(0 == destination)
            cpu.FlagZ = 1;
        else
            cpu.FlagZ = 0;
        cpu.FlagN = 0;
        cpu.FlagH = 1;
        cpu.FlagC = 0;
    }
    void or(ref u8 destination, u8 value) {
        destination = destination | value;
        if(0 == destination)
            cpu.FlagZ = 1;
        else
            cpu.FlagZ = 0;
        cpu.FlagN = 0;
        cpu.FlagH = 0;
        cpu.FlagC = 0;
    }
    void xor(ref u8 destination, u8 value) {
        destination = destination ^ value;
        if(0 == destination)
            cpu.FlagZ = 1;
        else
            cpu.FlagZ = 0;
        cpu.FlagN = 0;
        cpu.FlagH = 0;
        cpu.FlagC = 0;
    }
    void cp(u8 destination, u8 value) {
        u8 dummyDestination = destination;
        subu8(dummyDestination, value);
    }
    void inc(ref u8 destination) {
        if((destination & 0x0f) == 0x0f) 
            cpu.FlagH = 1;
        else 
            cpu.FlagH = 0;

	    destination++;
	
	    if(0 == destination) 
            cpu.FlagZ = 1;
	    else 
            cpu.FlagZ = 0;
	
	    cpu.FlagN = 0;
    }
    void dec(ref u8 destination) {
        if(destination & 0x0f) 
            cpu.FlagH = 0;
        else 
            cpu.FlagH = 1;

	    destination--;
	
	    if(0 == destination) 
            cpu.FlagZ = 1;
	    else 
            cpu.FlagZ = 0;
	
	    cpu.FlagN = 1;
    }
    // ADD A,n
    void opcode_87(const u16 operand) {
        addu8(cpu.A, cpu.A);
    }
    void opcode_80(const u16 operand) {
        addu8(cpu.A, cpu.B);
    }
    void opcode_81(const u16 operand) {
        addu8(cpu.A, cpu.C);
    }
    void opcode_82(const u16 operand) {
        addu8(cpu.A, cpu.D);
    }
    void opcode_83(const u16 operand) {
        addu8(cpu.A, cpu.E);
    }
    void opcode_84(const u16 operand) {
        addu8(cpu.A, cpu.H);
    }
    void opcode_85(const u16 operand) {
        addu8(cpu.A, cpu.L);
    }
    void opcode_86(const u16 operand) {
        addu8(cpu.A, mem.readU8(cpu.HL));
    }
    void opcode_C6(const u16 operand) {
        addu8(cpu.A, cast(u8)(operand & 0x00FF));
    }
    // ADC A,n
    void opcode_8F(const u16 operand) {
        addcu8(cpu.A, cpu.A);
    }
    void opcode_88(const u16 operand) {
        addcu8(cpu.A, cpu.B);
    }
    void opcode_89(const u16 operand) {
        addcu8(cpu.A, cpu.C);
    }
    void opcode_8A(const u16 operand) {
        addcu8(cpu.A, cpu.D);
    }
    void opcode_8B(const u16 operand) {
        addcu8(cpu.A, cpu.E);
    }
    void opcode_8C(const u16 operand) {
        addcu8(cpu.A, cpu.H);
    }
    void opcode_8D(const u16 operand) {
        addcu8(cpu.A, cpu.L);
    }
    void opcode_8E(const u16 operand) {
        addcu8(cpu.A, mem.readU8(cpu.HL));
    }
    void opcode_CE(const u16 operand) {
        addcu8(cpu.A, cast(u8)(operand & 0x00FF));
    }
    // SB A,n
    void opcode_97(const u16 operand) {
        subu8(cpu.A, cpu.A);
    }
    void opcode_90(const u16 operand) {
        subu8(cpu.A, cpu.B);
    }
    void opcode_91(const u16 operand) {
        subu8(cpu.A, cpu.C);
    }
    void opcode_92(const u16 operand) {
        subu8(cpu.A, cpu.D);
    }
    void opcode_93(const u16 operand) {
        subu8(cpu.A, cpu.E);
    }
    void opcode_94(const u16 operand) {
        subu8(cpu.A, cpu.H);
    }
    void opcode_95(const u16 operand) {
        subu8(cpu.A, cpu.L);
    }
    void opcode_96(const u16 operand) {
        subu8(cpu.A, mem.readU8(cpu.HL));
    }
    void opcode_D6(const u16 operand) {
        subu8(cpu.A, cast(u8)(operand & 0x00FF));
    }
    // SBC A,n
    void opcode_9F(const u16 operand) {
        subcu8(cpu.A, cpu.A);
    }
    void opcode_98(const u16 operand) {
        subcu8(cpu.A, cpu.B);
    }
    void opcode_99(const u16 operand) {
        subcu8(cpu.A, cpu.C);
    }
    void opcode_9A(const u16 operand) {
        subcu8(cpu.A, cpu.D);
    }
    void opcode_9B(const u16 operand) {
        subcu8(cpu.A, cpu.E);
    }
    void opcode_9C(const u16 operand) {
        subcu8(cpu.A, cpu.H);
    }
    void opcode_9D(const u16 operand) {
        subcu8(cpu.A, cpu.L);
    }
    void opcode_9E(const u16 operand) {
        subcu8(cpu.A, mem.readU8(cpu.HL));
    }
    void opcode_DE(const u16 operand) {
        subcu8(cpu.A, cast(u8)(operand & 0x00FF));
    }
    // AND n
    void opcode_A7(const u16 operand) {
        and(cpu.A, cpu.A);
    }
    void opcode_A0(const u16 operand) {
        and(cpu.A, cpu.B);
    }
    void opcode_A1(const u16 operand) {
        and(cpu.A, cpu.C);
    }
    void opcode_A2(const u16 operand) {
        and(cpu.A, cpu.D);
    }
    void opcode_A3(const u16 operand) {
        and(cpu.A, cpu.E);
    }
    void opcode_A4(const u16 operand) {
        and(cpu.A, cpu.H);
    }
    void opcode_A5(const u16 operand) {
        and(cpu.A, cpu.L);
    }
    void opcode_A6(const u16 operand) {
        and(cpu.A, mem.readU8(cpu.HL));
    }
    void opcode_E6(const u16 operand) {
        and(cpu.A, cast(u8)(operand & 0x00FF));
    }
    // OR n
    void opcode_B7(const u16 operand) {
        or(cpu.A, cpu.A);
    }
    void opcode_B0(const u16 operand) {
        or(cpu.A, cpu.B);
    }
    void opcode_B1(const u16 operand) {
        or(cpu.A, cpu.C);
    }
    void opcode_B2(const u16 operand) {
        or(cpu.A, cpu.D);
    }
    void opcode_B3(const u16 operand) {
        or(cpu.A, cpu.E);
    }
    void opcode_B4(const u16 operand) {
        or(cpu.A, cpu.H);
    }
    void opcode_B5(const u16 operand) {
        or(cpu.A, cpu.L);
    }
    void opcode_B6(const u16 operand) {
        or(cpu.A, mem.readU8(cpu.HL));
    }
    void opcode_F6(const u16 operand) {
        or(cpu.A, cast(u8)(operand & 0x00FF));
    }
    // XOR n
    void opcode_AF(const u16 operand) {
        xor(cpu.A, cpu.A);
    }
    void opcode_A8(const u16 operand) {
        xor(cpu.A, cpu.B);
    }
    void opcode_A9(const u16 operand) {
        xor(cpu.A, cpu.C);
    }
    void opcode_AA(const u16 operand) {
        xor(cpu.A, cpu.D);
    }
    void opcode_AB(const u16 operand) {
        xor(cpu.A, cpu.E);
    }
    void opcode_AC(const u16 operand) {
        xor(cpu.A, cpu.H);
    }
    void opcode_AD(const u16 operand) {
        xor(cpu.A, cpu.L);
    }
    void opcode_AE(const u16 operand) {
        xor(cpu.A, mem.readU8(cpu.HL));
    }
    void opcode_EE(const u16 operand) {
        xor(cpu.A, cast(u8)(operand & 0x00FF));
    }
    // CP n
    void opcode_BF(const u16 operand) {
        cp(cpu.A, cpu.A);
    }
    void opcode_B8(const u16 operand) {
        cp(cpu.A, cpu.B);
    }
    void opcode_B9(const u16 operand) {
        cp(cpu.A, cpu.C);
    }
    void opcode_BA(const u16 operand) {
        cp(cpu.A, cpu.D);
    }
    void opcode_BB(const u16 operand) {
        cp(cpu.A, cpu.E);
    }
    void opcode_BC(const u16 operand) {
        cp(cpu.A, cpu.H);
    }
    void opcode_BD(const u16 operand) {
        cp(cpu.A, cpu.L);
    }
    void opcode_BE(const u16 operand) {
        cp(cpu.A, mem.readU8(cpu.HL));
    }
    void opcode_FE(const u16 operand) {
        cp(cpu.A, cast(u8)(operand & 0x00FF));
    }
    // INC n
    void opcode_3C(const u16 operand) {
        inc(cpu.A);
    }
    void opcode_04(const u16 operand) {
        inc(cpu.B);
    }
    void opcode_0C(const u16 operand) {
        inc(cpu.C);
    }
    void opcode_14(const u16 operand) {
        inc(cpu.D);
    }
    void opcode_1C(const u16 operand) {
        inc(cpu.E);
    }
    void opcode_24(const u16 operand) {
        inc(cpu.H);
    }
    void opcode_2C(const u16 operand) {
        inc(cpu.L);
    }
    void opcode_34(const u16 operand) {
        u8 value = mem.readU8(cpu.HL);
        inc(value);
        mem.writeU8(cpu.HL, value);
    }
    // DEC n
    void opcode_3D(const u16 operand) {
        dec(cpu.A);
    }
    void opcode_05(const u16 operand) {
        dec(cpu.B);
    }
    void opcode_0D(const u16 operand) {
        dec(cpu.C);
    }
    void opcode_15(const u16 operand) {
        dec(cpu.D);
    }
    void opcode_1D(const u16 operand) {
        dec(cpu.E);
    }
    void opcode_25(const u16 operand) {
        dec(cpu.H);
    }
    void opcode_2D(const u16 operand) {
        dec(cpu.L);
    }
    void opcode_35(const u16 operand) {
        u8 value = mem.readU8(cpu.HL);
        dec(value);
        mem.writeU8(cpu.HL, value);
    }
    // 16-Bit Arithmetic
    // ADD HL,n
    void add_hl(ref u16 destination, u16 value) {
        const u32 result = destination + value;

        if(result & 0xffff0000) 
            cpu.FlagC = 1;
	    else 
            cpu.FlagC = 0;

        destination = cast(u16)(result & 0xffff);

        if(((destination & 0x0f) + (value & 0x0f)) > 0x0f) 
            cpu.FlagH = 1;
	    else 
            cpu.FlagH = 0;

        cpu.FlagN = 0;
    }
    void opcode_09(const u16 operand) {
        add_hl(cpu.HL, cpu.BC);
    }
    void opcode_19(const u16 operand) {
        add_hl(cpu.HL, cpu.DE);
    }
    void opcode_29(const u16 operand) {
        add_hl(cpu.HL, cpu.HL);
    }
    void opcode_39(const u16 operand) {
        add_hl(cpu.HL, cpu.SP);
    }
    // ADD SP,n
    void opcode_E8(const u16 operand) {
        assert(false);
    }
    // INC nn
    void opcode_03(const u16 operand) {
        cpu.BC++;
    }
    void opcode_13(const u16 operand) {
        cpu.DE++;
    }
    void opcode_23(const u16 operand) {
        cpu.HL++;
    }
    void opcode_33(const u16 operand) {
        cpu.SP++;
    }
    // DEC nn
    void opcode_0B(const u16 operand) {
        cpu.BC--;
    }
    void opcode_1B(const u16 operand) {
        cpu.DE--;
    }
    void opcode_2B(const u16 operand) {
        cpu.HL--;
    }
    void opcode_3B(const u16 operand) {
        cpu.SP--;
    }
    // Miscellaneous
    void swap(ref u8 destination) {
        u8 high = destination & 0xF0;
        u8 low = destination & 0x0F;
        destination = cast(u8)((low << 0x4) | (high >> 0x4));
        if(0 == destination)
            cpu.FlagZ = 1;
        else
            cpu.FlagZ = 0;
        cpu.FlagN = 0;
        cpu.FlagH = 0;
        cpu.FlagC = 0;
    }
    // SWAP n
    void opcode_cb_37(const u16 operand) { swap(cpu.A); }
    void opcode_cb_30(const u16 operand) { swap(cpu.B); }
    void opcode_cb_31(const u16 operand) { swap(cpu.C); }
    void opcode_cb_32(const u16 operand) { swap(cpu.D); }
    void opcode_cb_33(const u16 operand) { swap(cpu.E); }
    void opcode_cb_34(const u16 operand) { swap(cpu.H); }
    void opcode_cb_35(const u16 operand) { swap(cpu.L); }
    void opcode_cb_36(const u16 operand) { swap(cpu.L); }
    // DAA
    void opcode_27(const u16 operand) { assert(false); }
    // CPL
    void opcode_2F(const u16 operand) { 
        cpu.A = ~cpu.A;
        cpu.FlagN = 1;
        cpu.FlagH = 1;
    }
    // CCF
    void opcode_3F(const u16 operand) { assert(false); }
    // SCF
    void opcode_37(const u16 operand) { assert(false); }
    // NOP
    void opcode_00(const u16 operand) {}
    // HALT
    void opcode_76(const u16 operand) { assert(false); }
    // STOP
    void opcode_10(const u16 operand) { assert(false); }
    // DI
    void opcode_F3(const u16 operand) { 
        cpu.IME = false;
    }
    // EI
    void opcode_FB(const u16 operand) { 
        cpu.IME = true;
    }
    // Rotates & Shifts
    void opcode_07(const u16 operand) { assert(false); }
    void opcode_17(const u16 operand) { assert(false); }
    void opcode_0F(const u16 operand) { assert(false); }
    void opcode_1F(const u16 operand) { assert(false); }
    // RLC n
    void opcode_cb_07(const u16 operand) { assert(false); }
    void opcode_cb_00(const u16 operand) { assert(false); }
    void opcode_cb_01(const u16 operand) { assert(false); }
    void opcode_cb_02(const u16 operand) { assert(false); }
    void opcode_cb_03(const u16 operand) { assert(false); }
    void opcode_cb_04(const u16 operand) { assert(false); }
    void opcode_cb_05(const u16 operand) { assert(false); }
    void opcode_cb_06(const u16 operand) { assert(false); }
    // RL n
    void opcode_cb_17(const u16 operand) { assert(false); }
    void opcode_cb_10(const u16 operand) { assert(false); }
    void opcode_cb_11(const u16 operand) { assert(false); }
    void opcode_cb_12(const u16 operand) { assert(false); }
    void opcode_cb_13(const u16 operand) { assert(false); }
    void opcode_cb_14(const u16 operand) { assert(false); }
    void opcode_cb_15(const u16 operand) { assert(false); }
    void opcode_cb_16(const u16 operand) { assert(false); }
    // RRC n
    void opcode_cb_0F(const u16 operand) { assert(false); }
    void opcode_cb_08(const u16 operand) { assert(false); }
    void opcode_cb_09(const u16 operand) { assert(false); }
    void opcode_cb_0A(const u16 operand) { assert(false); }
    void opcode_cb_0B(const u16 operand) { assert(false); }
    void opcode_cb_0C(const u16 operand) { assert(false); }
    void opcode_cb_0D(const u16 operand) { assert(false); }
    void opcode_cb_0E(const u16 operand) { assert(false); }
    // RR n
    void opcode_cb_1F(const u16 operand) { assert(false); }
    void opcode_cb_18(const u16 operand) { assert(false); }
    void opcode_cb_19(const u16 operand) { assert(false); }
    void opcode_cb_1A(const u16 operand) { assert(false); }
    void opcode_cb_1B(const u16 operand) { assert(false); }
    void opcode_cb_1C(const u16 operand) { assert(false); }
    void opcode_cb_1D(const u16 operand) { assert(false); }
    void opcode_cb_1E(const u16 operand) { assert(false); }
    // SLA n
    void opcode_cb_27(const u16 operand) { assert(false); }
    void opcode_cb_20(const u16 operand) { assert(false); }
    void opcode_cb_21(const u16 operand) { assert(false); }
    void opcode_cb_22(const u16 operand) { assert(false); }
    void opcode_cb_23(const u16 operand) { assert(false); }
    void opcode_cb_24(const u16 operand) { assert(false); }
    void opcode_cb_25(const u16 operand) { assert(false); }
    void opcode_cb_26(const u16 operand) { assert(false); }
    // SRA n
    void opcode_cb_2F(const u16 operand) { assert(false); }
    void opcode_cb_28(const u16 operand) { assert(false); }
    void opcode_cb_29(const u16 operand) { assert(false); }
    void opcode_cb_2A(const u16 operand) { assert(false); }
    void opcode_cb_2B(const u16 operand) { assert(false); }
    void opcode_cb_2C(const u16 operand) { assert(false); }
    void opcode_cb_2D(const u16 operand) { assert(false); }
    void opcode_cb_2E(const u16 operand) { assert(false); }
    // SRL n
    void opcode_cb_3F(const u16 operand) { assert(false); }
    void opcode_cb_38(const u16 operand) { assert(false); }
    void opcode_cb_39(const u16 operand) { assert(false); }
    void opcode_cb_3A(const u16 operand) { assert(false); }
    void opcode_cb_3B(const u16 operand) { assert(false); }
    void opcode_cb_3C(const u16 operand) { assert(false); }
    void opcode_cb_3D(const u16 operand) { assert(false); }
    void opcode_cb_3E(const u16 operand) { assert(false); }
    // Bit Opcodes
    void bittest(u8 bitIndex, u8 destination) {
        if(bitop.test(destination, bitIndex))
            cpu.FlagZ = 0;
        else
            cpu.FlagZ = 1;
        cpu.FlagN = 0;
        cpu.FlagH = 1;
    }
    // BIT b,r
    void opcode_cb_47(const u16 operand) { bittest(0, cpu.A); }
    void opcode_cb_40(const u16 operand) { bittest(0, cpu.B); }
    void opcode_cb_41(const u16 operand) { bittest(0, cpu.C); }
    void opcode_cb_42(const u16 operand) { bittest(0, cpu.D); }
    void opcode_cb_43(const u16 operand) { bittest(0, cpu.E); }
    void opcode_cb_44(const u16 operand) { bittest(0, cpu.H); }
    void opcode_cb_45(const u16 operand) { bittest(0, cpu.L); }
    void opcode_cb_46(const u16 operand) { bittest(0, mem.readU8(cpu.HL)); }
    void opcode_cb_4F(const u16 operand) { bittest(1, cpu.A); }
    void opcode_cb_48(const u16 operand) { bittest(1, cpu.B); }
    void opcode_cb_49(const u16 operand) { bittest(1, cpu.C); }
    void opcode_cb_4A(const u16 operand) { bittest(1, cpu.D); }
    void opcode_cb_4B(const u16 operand) { bittest(1, cpu.E); }
    void opcode_cb_4C(const u16 operand) { bittest(1, cpu.H); }
    void opcode_cb_4D(const u16 operand) { bittest(1, cpu.L); }
    void opcode_cb_4E(const u16 operand) { bittest(1, mem.readU8(cpu.HL)); }
    void opcode_cb_57(const u16 operand) { bittest(2, cpu.A); }
    void opcode_cb_50(const u16 operand) { bittest(2, cpu.B); }
    void opcode_cb_51(const u16 operand) { bittest(2, cpu.C); }
    void opcode_cb_52(const u16 operand) { bittest(2, cpu.D); }
    void opcode_cb_53(const u16 operand) { bittest(2, cpu.E); }
    void opcode_cb_54(const u16 operand) { bittest(2, cpu.H); }
    void opcode_cb_55(const u16 operand) { bittest(2, cpu.L); }
    void opcode_cb_56(const u16 operand) { bittest(2, mem.readU8(cpu.HL)); }
    void opcode_cb_5F(const u16 operand) { bittest(3, cpu.A); }
    void opcode_cb_58(const u16 operand) { bittest(3, cpu.B); }
    void opcode_cb_59(const u16 operand) { bittest(3, cpu.C); }
    void opcode_cb_5A(const u16 operand) { bittest(3, cpu.D); }
    void opcode_cb_5B(const u16 operand) { bittest(3, cpu.E); }
    void opcode_cb_5C(const u16 operand) { bittest(3, cpu.H); }
    void opcode_cb_5D(const u16 operand) { bittest(3, cpu.L); }
    void opcode_cb_5E(const u16 operand) { bittest(3, mem.readU8(cpu.HL)); }
    void opcode_cb_67(const u16 operand) { bittest(4, cpu.A); }
    void opcode_cb_60(const u16 operand) { bittest(4, cpu.B); }
    void opcode_cb_61(const u16 operand) { bittest(4, cpu.C); }
    void opcode_cb_62(const u16 operand) { bittest(4, cpu.D); }
    void opcode_cb_63(const u16 operand) { bittest(4, cpu.E); }
    void opcode_cb_64(const u16 operand) { bittest(4, cpu.H); }
    void opcode_cb_65(const u16 operand) { bittest(4, cpu.L); }
    void opcode_cb_66(const u16 operand) { bittest(4, mem.readU8(cpu.HL)); }
    void opcode_cb_6F(const u16 operand) { bittest(5, cpu.A); }
    void opcode_cb_68(const u16 operand) { bittest(5, cpu.B); }
    void opcode_cb_69(const u16 operand) { bittest(5, cpu.C); }
    void opcode_cb_6A(const u16 operand) { bittest(5, cpu.D); }
    void opcode_cb_6B(const u16 operand) { bittest(5, cpu.E); }
    void opcode_cb_6C(const u16 operand) { bittest(5, cpu.H); }
    void opcode_cb_6D(const u16 operand) { bittest(5, cpu.L); }
    void opcode_cb_6E(const u16 operand) { bittest(5, mem.readU8(cpu.HL)); }
    void opcode_cb_77(const u16 operand) { bittest(6, cpu.A); }
    void opcode_cb_70(const u16 operand) { bittest(6, cpu.B); }
    void opcode_cb_71(const u16 operand) { bittest(6, cpu.C); }
    void opcode_cb_72(const u16 operand) { bittest(6, cpu.D); }
    void opcode_cb_73(const u16 operand) { bittest(6, cpu.E); }
    void opcode_cb_74(const u16 operand) { bittest(6, cpu.H); }
    void opcode_cb_75(const u16 operand) { bittest(6, cpu.L); }
    void opcode_cb_76(const u16 operand) { bittest(6, mem.readU8(cpu.HL)); }
    void opcode_cb_7F(const u16 operand) { bittest(7, cpu.A); }
    void opcode_cb_78(const u16 operand) { bittest(7, cpu.B); }
    void opcode_cb_79(const u16 operand) { bittest(7, cpu.C); }
    void opcode_cb_7A(const u16 operand) { bittest(7, cpu.D); }
    void opcode_cb_7B(const u16 operand) { bittest(7, cpu.E); }
    void opcode_cb_7C(const u16 operand) { bittest(7, cpu.H); }
    void opcode_cb_7D(const u16 operand) { bittest(7, cpu.L); }
    void opcode_cb_7E(const u16 operand) { bittest(7, mem.readU8(cpu.HL)); }
    // SET b,r
    void bitset(u8 bitIndex, ref u8 destination) {
        destination = bitop.set(destination, bitIndex);
    }
    void opcode_cb_C7(const u16 operand) { bitset(0, cpu.A); }
    void opcode_cb_C0(const u16 operand) { bitset(0, cpu.B); }
    void opcode_cb_C1(const u16 operand) { bitset(0, cpu.C); }
    void opcode_cb_C2(const u16 operand) { bitset(0, cpu.D); }
    void opcode_cb_C3(const u16 operand) { bitset(0, cpu.E); }
    void opcode_cb_C4(const u16 operand) { bitset(0, cpu.H); }
    void opcode_cb_C5(const u16 operand) { bitset(0, cpu.L); }
    void opcode_cb_C6(const u16 operand) { bitset(0, cpu.L); }
    void opcode_cb_CF(const u16 operand) { bitset(1, cpu.A); }
    void opcode_cb_C8(const u16 operand) { bitset(1, cpu.B); }
    void opcode_cb_C9(const u16 operand) { bitset(1, cpu.C); }
    void opcode_cb_CA(const u16 operand) { bitset(1, cpu.D); }
    void opcode_cb_CB(const u16 operand) { bitset(1, cpu.E); }
    void opcode_cb_CC(const u16 operand) { bitset(1, cpu.H); }
    void opcode_cb_CD(const u16 operand) { bitset(1, cpu.L); }
    void opcode_cb_CE(const u16 operand) { bitset(1, cpu.L); }
    void opcode_cb_D7(const u16 operand) { bitset(2, cpu.A); }
    void opcode_cb_D0(const u16 operand) { bitset(2, cpu.B); }
    void opcode_cb_D1(const u16 operand) { bitset(2, cpu.C); }
    void opcode_cb_D2(const u16 operand) { bitset(2, cpu.D); }
    void opcode_cb_D3(const u16 operand) { bitset(2, cpu.E); }
    void opcode_cb_D4(const u16 operand) { bitset(2, cpu.H); }
    void opcode_cb_D5(const u16 operand) { bitset(2, cpu.L); }
    void opcode_cb_D6(const u16 operand) { bitset(2, cpu.L); }
    void opcode_cb_DF(const u16 operand) { bitset(3, cpu.A); }
    void opcode_cb_D8(const u16 operand) { bitset(3, cpu.B); }
    void opcode_cb_D9(const u16 operand) { bitset(3, cpu.C); }
    void opcode_cb_DA(const u16 operand) { bitset(3, cpu.D); }
    void opcode_cb_DB(const u16 operand) { bitset(3, cpu.E); }
    void opcode_cb_DC(const u16 operand) { bitset(3, cpu.H); }
    void opcode_cb_DD(const u16 operand) { bitset(3, cpu.L); }
    void opcode_cb_DE(const u16 operand) { bitset(3, cpu.L); }
    void opcode_cb_E7(const u16 operand) { bitset(4, cpu.A); }
    void opcode_cb_E0(const u16 operand) { bitset(4, cpu.B); }
    void opcode_cb_E1(const u16 operand) { bitset(4, cpu.C); }
    void opcode_cb_E2(const u16 operand) { bitset(4, cpu.D); }
    void opcode_cb_E3(const u16 operand) { bitset(4, cpu.E); }
    void opcode_cb_E4(const u16 operand) { bitset(4, cpu.H); }
    void opcode_cb_E5(const u16 operand) { bitset(4, cpu.L); }
    void opcode_cb_E6(const u16 operand) { bitset(4, cpu.L); }
    void opcode_cb_EF(const u16 operand) { bitset(5, cpu.A); }
    void opcode_cb_E8(const u16 operand) { bitset(5, cpu.B); }
    void opcode_cb_E9(const u16 operand) { bitset(5, cpu.C); }
    void opcode_cb_EA(const u16 operand) { bitset(5, cpu.D); }
    void opcode_cb_EB(const u16 operand) { bitset(5, cpu.E); }
    void opcode_cb_EC(const u16 operand) { bitset(5, cpu.H); }
    void opcode_cb_ED(const u16 operand) { bitset(5, cpu.L); }
    void opcode_cb_EE(const u16 operand) { bitset(5, cpu.L); }
    void opcode_cb_F7(const u16 operand) { bitset(6, cpu.A); }
    void opcode_cb_F0(const u16 operand) { bitset(6, cpu.B); }
    void opcode_cb_F1(const u16 operand) { bitset(6, cpu.C); }
    void opcode_cb_F2(const u16 operand) { bitset(6, cpu.D); }
    void opcode_cb_F3(const u16 operand) { bitset(6, cpu.E); }
    void opcode_cb_F4(const u16 operand) { bitset(6, cpu.H); }
    void opcode_cb_F5(const u16 operand) { bitset(6, cpu.L); }
    void opcode_cb_F6(const u16 operand) { bitset(6, cpu.L); }
    void opcode_cb_FF(const u16 operand) { bitset(7, cpu.A); }
    void opcode_cb_F8(const u16 operand) { bitset(7, cpu.B); }
    void opcode_cb_F9(const u16 operand) { bitset(7, cpu.C); }
    void opcode_cb_FA(const u16 operand) { bitset(7, cpu.D); }
    void opcode_cb_FB(const u16 operand) { bitset(7, cpu.E); }
    void opcode_cb_FC(const u16 operand) { bitset(7, cpu.H); }
    void opcode_cb_FD(const u16 operand) { bitset(7, cpu.L); }
    void opcode_cb_FE(const u16 operand) { bitset(7, cpu.L); }
    // RES b,r
    void bitreset(u8 bitIndex, ref u8 destination) {
        destination = bitop.reset(destination, bitIndex);
    }
    void opcode_cb_87(const u16 operand) { bitreset(0, cpu.A); }
    void opcode_cb_80(const u16 operand) { bitreset(0, cpu.B); }
    void opcode_cb_81(const u16 operand) { bitreset(0, cpu.C); }
    void opcode_cb_82(const u16 operand) { bitreset(0, cpu.D); }
    void opcode_cb_83(const u16 operand) { bitreset(0, cpu.E); }
    void opcode_cb_84(const u16 operand) { bitreset(0, cpu.H); }
    void opcode_cb_85(const u16 operand) { bitreset(0, cpu.L); }
    void opcode_cb_86(const u16 operand) { bitreset(0, cpu.L); }
    void opcode_cb_8F(const u16 operand) { bitreset(1, cpu.A); }
    void opcode_cb_88(const u16 operand) { bitreset(1, cpu.B); }
    void opcode_cb_89(const u16 operand) { bitreset(1, cpu.C); }
    void opcode_cb_8A(const u16 operand) { bitreset(1, cpu.D); }
    void opcode_cb_8B(const u16 operand) { bitreset(1, cpu.E); }
    void opcode_cb_8C(const u16 operand) { bitreset(1, cpu.H); }
    void opcode_cb_8D(const u16 operand) { bitreset(1, cpu.L); }
    void opcode_cb_8E(const u16 operand) { bitreset(1, cpu.L); }
    void opcode_cb_97(const u16 operand) { bitreset(2, cpu.A); }
    void opcode_cb_90(const u16 operand) { bitreset(2, cpu.B); }
    void opcode_cb_91(const u16 operand) { bitreset(2, cpu.C); }
    void opcode_cb_92(const u16 operand) { bitreset(2, cpu.D); }
    void opcode_cb_93(const u16 operand) { bitreset(2, cpu.E); }
    void opcode_cb_94(const u16 operand) { bitreset(2, cpu.H); }
    void opcode_cb_95(const u16 operand) { bitreset(2, cpu.L); }
    void opcode_cb_96(const u16 operand) { bitreset(2, cpu.L); }
    void opcode_cb_9F(const u16 operand) { bitreset(3, cpu.A); }
    void opcode_cb_98(const u16 operand) { bitreset(3, cpu.B); }
    void opcode_cb_99(const u16 operand) { bitreset(3, cpu.C); }
    void opcode_cb_9A(const u16 operand) { bitreset(3, cpu.D); }
    void opcode_cb_9B(const u16 operand) { bitreset(3, cpu.E); }
    void opcode_cb_9C(const u16 operand) { bitreset(3, cpu.H); }
    void opcode_cb_9D(const u16 operand) { bitreset(3, cpu.L); }
    void opcode_cb_9E(const u16 operand) { bitreset(3, cpu.L); }
    void opcode_cb_A7(const u16 operand) { bitreset(4, cpu.A); }
    void opcode_cb_A0(const u16 operand) { bitreset(4, cpu.B); }
    void opcode_cb_A1(const u16 operand) { bitreset(4, cpu.C); }
    void opcode_cb_A2(const u16 operand) { bitreset(4, cpu.D); }
    void opcode_cb_A3(const u16 operand) { bitreset(4, cpu.E); }
    void opcode_cb_A4(const u16 operand) { bitreset(4, cpu.H); }
    void opcode_cb_A5(const u16 operand) { bitreset(4, cpu.L); }
    void opcode_cb_A6(const u16 operand) { bitreset(4, cpu.L); }
    void opcode_cb_AF(const u16 operand) { bitreset(5, cpu.A); }
    void opcode_cb_A8(const u16 operand) { bitreset(5, cpu.B); }
    void opcode_cb_A9(const u16 operand) { bitreset(5, cpu.C); }
    void opcode_cb_AA(const u16 operand) { bitreset(5, cpu.D); }
    void opcode_cb_AB(const u16 operand) { bitreset(5, cpu.E); }
    void opcode_cb_AC(const u16 operand) { bitreset(5, cpu.H); }
    void opcode_cb_AD(const u16 operand) { bitreset(5, cpu.L); }
    void opcode_cb_AE(const u16 operand) { bitreset(5, cpu.L); }
    void opcode_cb_B7(const u16 operand) { bitreset(6, cpu.A); }
    void opcode_cb_B0(const u16 operand) { bitreset(6, cpu.B); }
    void opcode_cb_B1(const u16 operand) { bitreset(6, cpu.C); }
    void opcode_cb_B2(const u16 operand) { bitreset(6, cpu.D); }
    void opcode_cb_B3(const u16 operand) { bitreset(6, cpu.E); }
    void opcode_cb_B4(const u16 operand) { bitreset(6, cpu.H); }
    void opcode_cb_B5(const u16 operand) { bitreset(6, cpu.L); }
    void opcode_cb_B6(const u16 operand) { bitreset(6, cpu.L); }
    void opcode_cb_BF(const u16 operand) { bitreset(7, cpu.A); }
    void opcode_cb_B8(const u16 operand) { bitreset(7, cpu.B); }
    void opcode_cb_B9(const u16 operand) { bitreset(7, cpu.C); }
    void opcode_cb_BA(const u16 operand) { bitreset(7, cpu.D); }
    void opcode_cb_BB(const u16 operand) { bitreset(7, cpu.E); }
    void opcode_cb_BC(const u16 operand) { bitreset(7, cpu.H); }
    void opcode_cb_BD(const u16 operand) { bitreset(7, cpu.L); }
    void opcode_cb_BE(const u16 operand) { bitreset(7, cpu.L); }
    // Jumps
    // JP nn
    void opcode_C3(const u16 operand) { 
        cpu.PC = operand;
     }
    // JP cc,nn
    void opcode_C2(const u16 operand) { 
        if(!cpu.FlagZ)
        {
            cpu.PC = operand;
            extra_cycle(2);
        }
    }
    void opcode_CA(const u16 operand) { 
        if(cpu.FlagZ)
        {
            cpu.PC = operand;
            extra_cycle(2);
        }
    }
    void opcode_D2(const u16 operand) { 
        if(!cpu.FlagC)
        {
            cpu.PC = operand;
            extra_cycle(2);
        }
    }
    void opcode_DA(const u16 operand) { 
        if(cpu.FlagC)
        {
            cpu.PC = operand;
            extra_cycle(2);
        }
    }
    // JP (HL)
    void opcode_E9(const u16 operand) { 
        cpu.PC = cpu.HL;
    }
    // JR n
    void opcode_18(const u16 operand) { 
        int offset = cast(i8)(0x00FF & operand);
        int address = cast(int)cpu.PC + offset;
        cpu.PC = cast(u16)address;
    }
    // JR cc,n
    void opcode_20(const u16 operand) { 
        if(0 == cpu.FlagZ) {
            opcode_18(operand);
            extra_cycle(2);
        }
    }
    void opcode_28(const u16 operand) { 
        if(1 == cpu.FlagZ) {
            opcode_18(operand);
            extra_cycle(2);
        }
    }
    void opcode_30(const u16 operand) { 
        if(0 == cpu.FlagC) {
            opcode_18(operand);
            extra_cycle(2);
        }
    }
    void opcode_38(const u16 operand) { 
        if(1 == cpu.FlagC) {
            opcode_18(operand);
            extra_cycle(2);
        }
    }
    // Calls
    // CALL nn
    void opcode_CD(const u16 operand) { 
        cpu.SP-=2;
        mem.writeU16(cpu.SP, cpu.PC);
        cpu.PC=operand;
    }
    // CALL cc,nn
    void opcode_C4(const u16 operand) { assert(false); }
    void opcode_CC(const u16 operand) { assert(false); }
    void opcode_D4(const u16 operand) { assert(false); }
    void opcode_DC(const u16 operand) { assert(false); }
    // Restarts
    // RST n
    void opcode_C7(const u16 operand) { opcode_CD(0x00); }
    void opcode_CF(const u16 operand) { opcode_CD(0x08); }
    void opcode_D7(const u16 operand) { opcode_CD(0x10); }
    void opcode_DF(const u16 operand) { opcode_CD(0x18); }
    void opcode_E7(const u16 operand) { opcode_CD(0x20); }
    void opcode_EF(const u16 operand) { opcode_CD(0x28); }
    void opcode_F7(const u16 operand) { opcode_CD(0x30); }
    void opcode_FF(const u16 operand) { opcode_CD(0x38); }
    // Returns
    // RET
    void opcode_C9(const u16 operand) {     
        cpu.PC = mem.readU16(cpu.SP);
        cpu.SP+=2;
    }
    // RET cc
    void returnIfFlagValue(const u16 address, bool test) {
        if(test)
        {
            extra_cycle(6);
            opcode_C9(address);
        }
    }
    void opcode_C0(const u16 operand) { 
        returnIfFlagValue(operand, !cpu.FlagZ);
    }
    void opcode_C8(const u16 operand) { 
        returnIfFlagValue(operand, cpu.FlagZ);
    }
    void opcode_D0(const u16 operand) { 
        returnIfFlagValue(operand, !cpu.FlagC);
    }
    void opcode_D8(const u16 operand) { 
        returnIfFlagValue(operand, cpu.FlagC);
    }
    // RETI
    void opcode_D9(const u16 operand) { 
        opcode_FB(operand); // EI
        opcode_C9(operand); // RET
    }
    // illegal opcode
    void opcode_D3(const u16 operand) { assert(false); }
    void opcode_DB(const u16 operand) { assert(false); }
    void opcode_DD(const u16 operand) { assert(false); }
    void opcode_E3(const u16 operand) { assert(false); }
    void opcode_E4(const u16 operand) { assert(false); }
    void opcode_EB(const u16 operand) { assert(false); }
    void opcode_EC(const u16 operand) { assert(false); }
    void opcode_ED(const u16 operand) { assert(false); }
    void opcode_F4(const u16 operand) { assert(false); }
    void opcode_FC(const u16 operand) { assert(false); }
    void opcode_FD(const u16 operand) { assert(false); }

    //RLC n




public:
    CPU cpu;
    PPU ppu;
    Memory mem;

    unittest
    {
        Emu emu;

        void RenderFunction(const u8[] lcd) { }
        emu.SetRenderDelegate(&RenderFunction);

        emu.Reset();
        const u16 PC = emu.cpu.PC;
        emu.mem.writeU8(cast(u16)(PC+0), cast(u8)0xCD);
        emu.mem.writeU16(cast(u16)(PC+1), cast(u16)(PC+4));
        emu.mem.writeU8(cast(u16)(PC+3), cast(u8)0x00);
        emu.mem.writeU8(cast(u16)(PC+4), cast(u8)0xCD);
        emu.mem.writeU16(cast(u16)(PC+5), cast(u16)(PC+8));
        emu.mem.writeU8(cast(u16)(PC+7), cast(u8)0xC9);
        emu.mem.writeU8(cast(u16)(PC+8), cast(u8)0xC9);

        emu.Frame();
        emu.Frame();
        assert(emu.cpu.PC == cast(u16)(PC+8));
        emu.Frame();
        emu.Frame();
        assert(emu.cpu.PC == cast(u16)(PC+3));
    }
}
