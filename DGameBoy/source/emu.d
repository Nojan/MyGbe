// http://blog.rekawek.eu/2017/02/09/coffee-gb/
// https://github.com/retrio/gb-test-roms
// https://realboyemulator.wordpress.com/2013/01/18/emulating-the-core-2/
// My Own Gameboy Emulator
import opcode;
import memory;
import numeric_alias;
import ppu;
import cpu;

struct Emu {
public:
    void Frame() 
    {
        cpu.CycleCount = 0;
        CpuStep();
        Interrupt();
        ppu.Step(cpu.CycleCount);
    }

    static string GenSwitch(string opcode, string operand)
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

    void CpuStep() {
        const u8 opcode = mem.readU8(cpu.PC);
        {
            import std.stdio;
            import std.format;
            writeln(format!"ROM0:%04X %02X State: AF%04X BC%04X DE%04X HL%04X SP%04X"(cpu.PC, opcode, cpu.AF, cpu.BC, cpu.DE, cpu.HL, cpu.SP));
        }
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

    void CpuExec(const u8 opcode, const u16 operand, immutable instruction ins) {
        cpu.PC += ins.length;
        cpu.CycleCount += ins.cycle;
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
            I_VBLANK = 0,
            I_LCDC   = 1<<1,
            I_TIMER  = 1<<2,
            I_SERIAL = 1<<3,
            I_JOY    = 1<<4,
        }

        if(fire & I_VBLANK) {
            flag &= ~I_VBLANK;
            vblankInterrupt();
        }

        mem.writeU8(mem.IF, flag);
    }

    void vblankInterrupt() {
        // draw time
        cpu.IME = 0;
        immutable u8 jump_opcode = 0xCD;
        immutable instruction = instruction_table[jump_opcode];
        CpuExec(jump_opcode, mem.VBLANK, instruction);
    }

private:
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
        cpu.A = cast(u8)cpu.HL;
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
        cpu.B = cast(u8)cpu.HL;
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
        cpu.C = cast(u8)cpu.HL;
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
        cpu.D = cast(u8)cpu.HL;
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
        cpu.E = cast(u8)cpu.HL;
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
        cpu.H = cast(u8)cpu.HL;
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
        cpu.L = cast(u8)cpu.HL;
    }
    void opcode_70(const u16 operand) {
        cpu.HL = cpu.B;
    }
    void opcode_71(const u16 operand) {
        cpu.HL = cpu.C;
    }
    void opcode_72(const u16 operand) {
        cpu.HL = cpu.D;
    }
    void opcode_73(const u16 operand) {
        cpu.HL = cpu.E;
    }
    void opcode_74(const u16 operand) {
        cpu.HL = cpu.H;
    }
    void opcode_75(const u16 operand) {
        cpu.HL = cpu.L;
    }
    void opcode_36(const u16 operand) {
        cpu.HL = cpu.HL;
    }
    // LD A,n
    void opcode_0A(const u16 operand) {
        cpu.A = cast(u8)cpu.BC;
    }
    void opcode_1A(const u16 operand) {
        cpu.A = cast(u8)cpu.DE;
    }
    void opcode_FA(const u16 operand) {
        cpu.A = cast(u8)operand;
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
        cpu.BC = cpu.A;
    }
    void opcode_12(const u16 operand) {
        cpu.DE = cpu.A;
    }
    void opcode_77(const u16 operand) {
        cpu.HL = cpu.A;
    }
    void opcode_EA(const u16 operand) {
        assert(false); // todo implement
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
        mem.writeU16(cpu.SP, cpu.AF);
        cpu.SP--;
        cpu.SP--;
    }
    void opcode_C5(const u16 operand) {
        mem.writeU16(cpu.SP, cpu.BC);
        cpu.SP--;
        cpu.SP--;
    }
    void opcode_D5(const u16 operand) {
        mem.writeU16(cpu.SP, cpu.DE);
        cpu.SP--;
        cpu.SP--;
    }
    void opcode_E5(const u16 operand) {
        mem.writeU16(cpu.SP, cpu.HL);
        cpu.SP--;
        cpu.SP--;
    }
    // POP nn
    void opcode_F1(const u16 operand) {
        cpu.AF = mem.readU16(cpu.SP);
        cpu.SP++;
        cpu.SP++;
    }
    void opcode_C1(const u16 operand) {
        cpu.BC = mem.readU16(cpu.SP);
        cpu.SP++;
        cpu.SP++;
    }
    void opcode_D1(const u16 operand) {
        cpu.DE = mem.readU16(cpu.SP);
        cpu.SP++;
        cpu.SP++;
    }
    void opcode_E1(const u16 operand) {
        cpu.HL = mem.readU16(cpu.SP);
        cpu.SP++;
        cpu.SP++;
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
            cpu.FlagH = 0;
        else 
            cpu.FlagH = 1;
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
            cpu.FlagH = 0;
        else 
            cpu.FlagH = 1;

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
        addu8(cpu.A, cast(u8)cpu.HL);
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
        addcu8(cpu.A, cast(u8)cpu.HL);
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
        subu8(cpu.A, cast(u8)cpu.HL);
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
        subcu8(cpu.A, cast(u8)cpu.HL);
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
        and(cpu.A, cast(u8)cpu.HL);
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
        or(cpu.A, cast(u8)cpu.HL);
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
        xor(cpu.A, cast(u8)cpu.HL);
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
        cp(cpu.A, cast(u8)cpu.HL);
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
        inc(cpu.L);
        cpu.HL = cpu.L;
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
        dec(cpu.L);
        cpu.HL = cpu.L;
    }
    // 16-Bit Arithmetic
    // ADD HL,n
    void add_hl(ref u16 destination, u16 value) {
        assert(false);
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
        if(0 == destination)
            cpu.FlagZ = 1;
        else
            cpu.FlagZ = 0;
        cpu.FlagN = 0;
        cpu.FlagH = 0;
        cpu.FlagC = 0;
        assert(false);
    }
    // DAA
    void opcode_27(const u16 operand) { assert(false); }
    // CPL
    void opcode_2F(const u16 operand) { assert(false); }
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
    // Jumps
    // JP nn
    void opcode_C3(const u16 operand) { 
        cpu.PC = operand;
     }
    // JP cc,nn
    void opcode_C2(const u16 operand) { assert(false); }
    void opcode_CA(const u16 operand) { assert(false); }
    void opcode_D2(const u16 operand) { assert(false); }
    void opcode_DA(const u16 operand) { assert(false); }
    // JP (HL)
    void opcode_E9(const u16 operand) { assert(false); }
    // JR n
    void opcode_18(const u16 operand) { assert(false); }
    // JR cc,n
    void opcode_20(const u16 operand) { 
        if(0 == cpu.FlagZ) {
            int offset = cast(i8)(0x00FF & operand);
            int address = cast(int)cpu.PC + offset;
            cpu.PC = cast(u16)address;
        }
    }
    void opcode_28(const u16 operand) { 
        if(1 == cpu.FlagZ) {
            int offset = cast(i8)(0x00FF & operand);
            int address = cast(int)cpu.PC + offset;
            cpu.PC = cast(u16)address;
        }
    }
    void opcode_30(const u16 operand) { 
        if(0 == cpu.FlagC) {
            int offset = cast(i8)(0x00FF & operand);
            int address = cast(int)cpu.PC + offset;
            cpu.PC = cast(u16)address;
        }
    }
    void opcode_38(const u16 operand) { 
        if(1 == cpu.FlagC) {
            int offset = cast(i8)(0x00FF & operand);
            int address = cast(int)cpu.PC + offset;
            cpu.PC = cast(u16)address;
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
    void opcode_C7(const u16 operand) { assert(false); }
    void opcode_CF(const u16 operand) { assert(false); }
    void opcode_D7(const u16 operand) { assert(false); }
    void opcode_DF(const u16 operand) { assert(false); }
    void opcode_E7(const u16 operand) { assert(false); }
    void opcode_EF(const u16 operand) { assert(false); }
    void opcode_F7(const u16 operand) { assert(false); }
    void opcode_FF(const u16 operand) { assert(false); }
    // Returns
    // RET
    void opcode_C9(const u16 operand) {     
        cpu.PC = mem.readU16(cpu.SP);
        cpu.SP+=2;
    }
    // RET cc
    void opcode_C0(const u16 operand) { assert(false); }
    void opcode_C8(const u16 operand) { assert(false); }
    void opcode_D0(const u16 operand) { assert(false); }
    void opcode_D8(const u16 operand) { assert(false); }
    // RETI
    void opcode_D9(const u16 operand) { 
        opcode_FB(operand); // EI
        opcode_C9(operand); // RET
    }
    // prefix CB
    void opcode_CB(const u16 operand) { assert(false); }
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
public:
    CPU cpu;
    PPU ppu;
    Memory mem;
}
