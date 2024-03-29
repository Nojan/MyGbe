// https://github.com/CTurt/Cinoop/blob/master/source/cpu.c

import numeric_alias;

struct instruction {
    string mnemonic;
    u8 length;
    u8 cycle;
}

immutable instruction[256] instruction_table = [
	{ "NOP", 0, 2 },                           // 0x00
	{ "LD BC, 0x%04X", 2, 6 },            // 0x01
	{ "LD (BC), A", 0, 4 },               // 0x02
	{ "INC BC", 0, 4 },                     // 0x03
	{ "INC B", 0, 2 },                       // 0x04
	{ "DEC B", 0, 2 },                       // 0x05
	{ "LD B, 0x%02X", 1, 4 },               // 0x06
	{ "RLCA", 0, 4 },                         // 0x07
	{ "LD (0x%04X), SP", 2, 10 },         // 0x08
	{ "ADD HL, BC", 0, 4 },              // 0x09
	{ "LD A, (BC)", 0, 4 },               // 0x0a
	{ "DEC BC", 0, 4 },                     // 0x0b
	{ "INC C", 0, 2 },                       // 0x0c
	{ "DEC C", 0, 2 },                       // 0x0d
	{ "LD C, 0x%02X", 1, 4 },               // 0x0e
	{ "RRCA", 0, 2 },                         // 0x0f
	{ "STOP", 1, 2 },                         // 0x10
	{ "LD DE, 0x%04X", 2, 6 },            // 0x11
	{ "LD (DE), A", 0, 4 },               // 0x12
	{ "INC DE", 0, 4 },                     // 0x13
	{ "INC D", 0, 2 },                       // 0x14
	{ "DEC D", 0, 2 },                       // 0x15
	{ "LD D, 0x%02X", 1, 4 },               // 0x16
	{ "RLA", 0, 4 },                           // 0x17
	{ "JR 0x%02X", 1, 6 },                    // 0x18
	{ "ADD HL, DE", 0, 4 },              // 0x19
	{ "LD A, (DE)", 0, 4 },               // 0x1a
	{ "DEC DE", 0, 4 },                     // 0x1b
	{ "INC E", 0, 2 },                       // 0x1c
	{ "DEC E", 0, 2 },                       // 0x1d
	{ "LD E, 0x%02X", 1, 4 },               // 0x1e
	{ "RRA", 0, 2 },                           // 0x1f
	{ "JR NZ, 0x%02X", 1, 4 },             // 0x20
	{ "LD HL, 0x%04X", 2, 6 },            // 0x21
	{ "LDI (HL), A", 0, 4 },             // 0x22
	{ "INC HL", 0, 4 },                     // 0x23
	{ "INC H", 0, 2 },                       // 0x24
	{ "DEC H", 0, 2 },                       // 0x25
	{ "LD H, 0x%02X", 1, 4 },               // 0x26
	{ "DAA", 0, 2 },                           // 0x27
	{ "JR Z, 0x%02X", 1, 4 },               // 0x28
	{ "ADD HL, HL", 0, 4 },              // 0x29
	{ "LDI A, (HL)", 0, 4 },             // 0x2a
	{ "DEC HL", 0, 4 },                     // 0x2b
	{ "INC L", 0, 2 },                       // 0x2c
	{ "DEC L", 0, 2 },                       // 0x2d
	{ "LD L, 0x%02X", 1, 4 },               // 0x2e
	{ "CPL", 0, 2 },                           // 0x2f
	{ "JR NC, 0x%02X", 1, 4 },             // 0x30
	{ "LD SP, 0x%04X", 2, 6 },            // 0x31
	{ "LDD (HL), A", 0, 4 },             // 0x32
	{ "INC SP", 0, 4 },                     // 0x33
	{ "INC (HL)", 0, 6 },                  // 0x34
	{ "DEC (HL)", 0, 6 },                  // 0x35
	{ "LD (HL), 0x%02X", 1, 6 },          // 0x36
	{ "SCF", 0, 2 },                           // 0x37
	{ "JR C, 0x%02X", 1, 4 },               // 0x38
	{ "ADD HL, SP", 0, 4 },              // 0x39
	{ "LDD A, (HL)", 0, 4 },             // 0x3a
	{ "DEC SP", 0, 4 },                     // 0x3b
	{ "INC A", 0, 2 },                       // 0x3c
	{ "DEC A", 0, 2 },                       // 0x3d
	{ "LD A, 0x%02X", 1, 4 },               // 0x3e
	{ "CCF", 0, 2 },                           // 0x3f
	{ "LD B, B", 0, 2 },                       // 0x40
	{ "LD B, C", 0, 2 },                    // 0x41
	{ "LD B, D", 0, 2 },                    // 0x42
	{ "LD B, E", 0, 2 },                    // 0x43
	{ "LD B, H", 0, 2 },                    // 0x44
	{ "LD B, L", 0, 2 },                    // 0x45
	{ "LD B, (HL)", 0, 4 },               // 0x46
	{ "LD B, A", 0, 2 },                    // 0x47
	{ "LD C, B", 0, 2 },                    // 0x48
	{ "LD C, C", 0, 2 },                       // 0x49
	{ "LD C, D", 0, 2 },                    // 0x4a
	{ "LD C, E", 0, 2 },                    // 0x4b
	{ "LD C, H", 0, 2 },                    // 0x4c
	{ "LD C, L", 0, 2 },                    // 0x4d
	{ "LD C, (HL)", 0, 4 },               // 0x4e
	{ "LD C, A", 0, 2 },                    // 0x4f
	{ "LD D, B", 0, 2 },                    // 0x50
	{ "LD D, C", 0, 2 },                    // 0x51
	{ "LD D, D", 0, 2 },                       // 0x52
	{ "LD D, E", 0, 2 },                    // 0x53
	{ "LD D, H", 0, 2 },                    // 0x54
	{ "LD D, L", 0, 2 },                    // 0x55
	{ "LD D, (HL)", 0, 4 },               // 0x56
	{ "LD D, A", 0, 2 },                    // 0x57
	{ "LD E, B", 0, 2 },                    // 0x58
	{ "LD E, C", 0, 2 },                    // 0x59
	{ "LD E, D", 0, 2 },                    // 0x5a
	{ "LD E, E", 0, 2 },                       // 0x5b
	{ "LD E, H", 0, 2 },                    // 0x5c
	{ "LD E, L", 0, 2 },                    // 0x5d
	{ "LD E, (HL)", 0, 4 },               // 0x5e
	{ "LD E, A", 0, 2 },                    // 0x5f
	{ "LD H, B", 0, 2 },                    // 0x60
	{ "LD H, C", 0, 2 },                    // 0x61
	{ "LD H, D", 0, 2 },                    // 0x62
	{ "LD H, E", 0, 2 },                    // 0x63
	{ "LD H, H", 0, 2 },                       // 0x64
	{ "LD H, L", 0, 2 },                    // 0x65
	{ "LD H, (HL)", 0, 4 },               // 0x66
	{ "LD H, A", 0, 2 },                    // 0x67
	{ "LD L, B", 0, 2 },                    // 0x68
	{ "LD L, C", 0, 2 },                    // 0x69
	{ "LD L, D", 0, 2 },                    // 0x6a
	{ "LD L, E", 0, 2 },                    // 0x6b
	{ "LD L, H", 0, 2 },                    // 0x6c
	{ "LD L, L", 0, 2 },                       // 0x6d
	{ "LD L, (HL)", 0, 4 },               // 0x6e
	{ "LD L, A", 0, 2 },                    // 0x6f
	{ "LD (HL), B", 0, 4 },               // 0x70
	{ "LD (HL), C", 0, 4 },               // 0x71
	{ "LD (HL), D", 0, 4 },               // 0x72
	{ "LD (HL), E", 0, 4 },               // 0x73
	{ "LD (HL), H", 0, 4 },               // 0x74
	{ "LD (HL), L", 0, 4 },               // 0x75
	{ "HALT", 0, 2 },                         // 0x76
	{ "LD (HL), A", 0, 4 },               // 0x77
	{ "LD A, B", 0, 2 },                    // 0x78
	{ "LD A, C", 0, 2 },                    // 0x79
	{ "LD A, D", 0, 2 },                    // 0x7a
	{ "LD A, E", 0, 2 },                    // 0x7b
	{ "LD A, H", 0, 2 },                    // 0x7c
	{ "LD A, L", 0, 2 },                    // 0x7d
	{ "LD A, (HL)", 0, 4 },               // 0x7e
	{ "LD A, A", 0, 2 },                       // 0x7f
	{ "ADD A, B", 0, 2 },                  // 0x80
	{ "ADD A, C", 0, 2 },                  // 0x81
	{ "ADD A, D", 0, 2 },                  // 0x82
	{ "ADD A, E", 0, 2 },                  // 0x83
	{ "ADD A, H", 0, 2 },                  // 0x84
	{ "ADD A, L", 0, 2 },                  // 0x85
	{ "ADD A, (HL)", 0, 4 },             // 0x86
	{ "ADD A", 0, 2 },                     // 0x87
	{ "ADC B", 0, 2 },                       // 0x88
	{ "ADC C", 0, 2 },                       // 0x89
	{ "ADC D", 0, 2 },                       // 0x8a
	{ "ADC E", 0, 2 },                       // 0x8b
	{ "ADC H", 0, 2 },                       // 0x8c
	{ "ADC L", 0, 2 },                       // 0x8d
	{ "ADC (HL)", 0, 4 },                  // 0x8e
	{ "ADC A", 0, 2 },                       // 0x8f
	{ "SUB B", 0, 2 },                       // 0x90
	{ "SUB C", 0, 2 },                       // 0x91
	{ "SUB D", 0, 2 },                       // 0x92
	{ "SUB E", 0, 2 },                       // 0x93
	{ "SUB H", 0, 2 },                       // 0x94
	{ "SUB L", 0, 2 },                       // 0x95
	{ "SUB (HL)", 0, 4 },                  // 0x96
	{ "SUB A", 0, 2 },                       // 0x97
	{ "SBC B", 0, 2 },                       // 0x98
	{ "SBC C", 0, 2 },                       // 0x99
	{ "SBC D", 0, 2 },                       // 0x9a
	{ "SBC E", 0, 2 },                       // 0x9b
	{ "SBC H", 0, 2 },                       // 0x9c
	{ "SBC L", 0, 2 },                       // 0x9d
	{ "SBC (HL)", 0, 4 },                  // 0x9e
	{ "SBC A", 0, 2 },                       // 0x9f
	{ "AND B", 0, 2 },                       // 0xa0
	{ "AND C", 0, 2 },                       // 0xa1
	{ "AND D", 0, 2 },                       // 0xa2
	{ "AND E", 0, 2 },                       // 0xa3
	{ "AND H", 0, 2 },                       // 0xa4
	{ "AND L", 0, 2 },                       // 0xa5
	{ "AND (HL)", 0, 4 },                  // 0xa6
	{ "AND A", 0, 2 },                       // 0xa7
	{ "XOR B", 0, 2 },                       // 0xa8
	{ "XOR C", 0, 2 },                       // 0xa9
	{ "XOR D", 0, 2 },                       // 0xaa
	{ "XOR E", 0, 2 },                       // 0xab
	{ "XOR H", 0, 2 },                       // 0xac
	{ "XOR L", 0, 2 },                       // 0xad
	{ "XOR (HL)", 0, 4 },                  // 0xae
	{ "XOR A", 0, 2 },                       // 0xaf
	{ "OR B", 0, 2 },                         // 0xb0
	{ "OR C", 0, 2 },                         // 0xb1
	{ "OR D", 0, 2 },                         // 0xb2
	{ "OR E", 0, 2 },                         // 0xb3
	{ "OR H", 0, 2 },                         // 0xb4
	{ "OR L", 0, 2 },                         // 0xb5
	{ "OR (HL)", 0, 4 },                    // 0xb6
	{ "OR A", 0, 2 },                         // 0xb7
	{ "CP B", 0, 2 },                         // 0xb8
	{ "CP C", 0, 2 },                         // 0xb9
	{ "CP D", 0, 2 },                         // 0xba
	{ "CP E", 0, 2 },                         // 0xbb
	{ "CP H", 0, 2 },                         // 0xbc
	{ "CP L", 0, 2 },                         // 0xbd
	{ "CP (HL)", 0, 4 },                    // 0xbe
	{ "CP A", 0, 2 },                         // 0xbf
	{ "RET NZ", 0, 4 },                     // 0xc0
	{ "POP BC", 0, 6 },                     // 0xc1
	{ "JP NZ, 0x%04X", 2, 6 },            // 0xc2
	{ "JP 0x%04X", 2, 8 },                   // 0xc3
	{ "CALL NZ, 0x%04X", 2, 6 },        // 0xc4
	{ "PUSH BC", 0, 8 },                   // 0xc5
	{ "ADD A, 0x%02X", 1, 4 },             // 0xc6
	{ "RST 0x00", 0, 8 },                    // 0xc7
	{ "RET Z", 0, 4 },                       // 0xc8
	{ "RET", 0, 8 },                           // 0xc9
	{ "JP Z, 0x%04X", 2, 6 },              // 0xca
	{ "CB %02X", 1, 0 },                      // 0xcb
	{ "CALL Z, 0x%04X", 2, 6 },          // 0xcc
	{ "CALL 0x%04X", 2, 12 },               // 0xcd
	{ "ADC 0x%02X", 1, 4 },                  // 0xce
	{ "RST 0x08", 0, 8 },                   // 0xcf
	{ "RET NC", 0, 4 },                     // 0xd0
	{ "POP DE", 0, 6 },                     // 0xd1
	{ "JP NC, 0x%04X", 2, 6 },            // 0xd2
	{ "UNKNOWN", 0, 0 },                 // 0xd3
	{ "CALL NC, 0x%04X", 2, 6 },        // 0xd4
	{ "PUSH DE", 0, 8 },                   // 0xd5
	{ "SUB 0x%02X", 1, 4 },                  // 0xd6
	{ "RST 0x10", 0, 8 },                   // 0xd7
	{ "RET C", 0, 4 },                       // 0xd8
	{ "RETI", 0, 8 },          // 0xd9
	{ "JP C, 0x%04X", 2, 6 },              // 0xda
	{ "UNKNOWN", 0, 0 },                 // 0xdb
	{ "CALL C, 0x%04X", 2, 0 },          // 0xdc
	{ "UNKNOWN", 0, 0 },                 // 0xdd
	{ "SBC 0x%02X", 1, 4 },                  // 0xde
	{ "RST 0x18", 0, 8 },                   // 0xdf
	{ "LD (0xFF00 + 0x%02X), A", 1, 6 },// 0xe0
	{ "POP HL", 0, 6 },                     // 0xe1
	{ "LD (0xFF00 + C), A", 0, 4 },      // 0xe2
	{ "UNKNOWN", 0, 0 },                 // 0xe3
	{ "UNKNOWN", 0, 0 },                 // 0xe4
	{ "PUSH HL", 0, 8 },                   // 0xe5
	{ "AND 0x%02X", 1, 4 },                  // 0xe6
	{ "RST 0x20", 0, 8 },                   // 0xe7
	{ "ADD SP,0x%02X", 1, 8 },            // 0xe8
	{ "JP HL", 0, 2 },                       // 0xe9
	{ "LD (0x%04X), A", 2, 8 },           // 0xea
	{ "UNKNOWN", 0, 0 },                 // 0xeb
	{ "UNKNOWN", 0, 0 },                 // 0xec
	{ "UNKNOWN", 0, 0 },                 // 0xed
	{ "XOR 0x%02X", 1, 4 },                  // 0xee
	{ "RST 0x28", 0, 8 },                   // 0xef
	{ "LD A, (0xFF00 + 0x%02X)", 1, 6 },// 0xf0
	{ "POP AF", 0, 6 },                     // 0xf1
	{ "LD A, (0xFF00 + C)", 0, 4 },      // 0xf2
	{ "DI", 0, 2 },                        // 0xf3
	{ "UNKNOWN", 0, 0 },                 // 0xf4
	{ "PUSH AF", 0, 8 },                   // 0xf5
	{ "OR 0x%02X", 1, 4 },                    // 0xf6
	{ "RST 0x30", 0, 8 },                   // 0xf7
	{ "LD HL, SP+0x%02X", 1, 6 },       // 0xf8
	{ "LD SP, HL", 0, 4 },                // 0xf9
	{ "LD A, (0x%04X)", 2, 8 },           // 0xfa
	{ "EI", 0, 2 },                             // 0xfb
	{ "UNKNOWN", 0, 0 },                 // 0xfc
	{ "UNKNOWN", 0, 0 },                 // 0xfd
	{ "CP 0x%02X", 1, 4 },                    // 0xfe
	{ "RST 0x38", 0, 8 },                  // 0xff
];

immutable instruction[256] cb_instruction_table = [
	{ "CB NOP", 0, 8 },                           // 0x00
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0x01
	{ "CB LD (BC), A", 0, 8 },               // 0x02
	{ "CB INC BC", 0, 8 },                     // 0x03
	{ "CB INC B", 0, 8 },                       // 0x04
	{ "CB DEC B", 0, 8 },                       // 0x05
	{ "CB LD B, 0x%02X", 0, 16 },               // 0x06
	{ "CB RLCA", 0, 8 },                         // 0x07
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0x08
	{ "CB ADD HL, BC", 0, 8 },              // 0x09
	{ "CB LD A, (BC)", 0, 8 },               // 0x0a
	{ "CB DEC BC", 0, 8 },                     // 0x0b
	{ "CB INC C", 0, 8 },                       // 0x0c
	{ "CB DEC C", 0, 8 },                       // 0x0d
	{ "CB LD C, 0x%02X", 0, 16 },               // 0x0e
	{ "CB RRCA", 0, 8 },                         // 0x0f
	{ "CB NOP", 0, 8 },                           // 0x10
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0x11
	{ "CB LD (BC), A", 0, 8 },               // 0x12
	{ "CB INC BC", 0, 8 },                     // 0x13
	{ "CB INC B", 0, 8 },                       // 0x14
	{ "CB DEC B", 0, 8 },                       // 0x15
	{ "CB LD B, 0x%02X", 0, 16 },               // 0x16
	{ "CB RLCA", 0, 8 },                         // 0x17
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0x18
	{ "CB ADD HL, BC", 0, 8 },              // 0x19
	{ "CB LD A, (BC)", 0, 8 },               // 0x1a
	{ "CB DEC BC", 0, 8 },                     // 0x1b
	{ "CB INC C", 0, 8 },                       // 0x1c
	{ "CB DEC C", 0, 8 },                       // 0x1d
	{ "CB LD C, 0x%02X", 0, 16 },               // 0x1e
	{ "CB RRCA", 0, 8 },                         // 0x1f
	{ "CB NOP", 0, 8 },                           // 0x20
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0x21
	{ "CB LD (BC), A", 0, 8 },               // 0x22
	{ "CB INC BC", 0, 8 },                     // 0x23
	{ "CB INC B", 0, 8 },                       // 0x24
	{ "CB DEC B", 0, 8 },                       // 0x25
	{ "CB LD B, 0x%02X", 0, 16 },               // 0x26
	{ "CB RLCA", 0, 8 },                         // 0x27
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0x28
	{ "CB ADD HL, BC", 0, 8 },              // 0x29
	{ "CB LD A, (BC)", 0, 8 },               // 0x2a
	{ "CB DEC BC", 0, 8 },                     // 0x2b
	{ "CB INC C", 0, 8 },                       // 0x2c
	{ "CB DEC C", 0, 8 },                       // 0x2d
	{ "CB LD C, 0x%02X", 0, 16 },               // 0x2e
	{ "CB RRCA", 0, 8 },                         // 0x2f
	{ "CB NOP", 0, 8 },                           // 0x30
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0x31
	{ "CB LD (BC), A", 0, 8 },               // 0x32
	{ "CB INC BC", 0, 8 },                     // 0x33
	{ "CB INC B", 0, 8 },                       // 0x34
	{ "CB DEC B", 0, 8 },                       // 0x35
	{ "CB LD B, 0x%02X", 0, 16 },               // 0x36
	{ "CB RLCA", 0, 8 },                         // 0x37
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0x38
	{ "CB ADD HL, BC", 0, 8 },              // 0x39
	{ "CB LD A, (BC)", 0, 8 },               // 0x3a
	{ "CB DEC BC", 0, 8 },                     // 0x3b
	{ "CB INC C", 0, 8 },                       // 0x3c
	{ "CB DEC C", 0, 8 },                       // 0x3d
	{ "CB LD C, 0x%02X", 0, 16 },               // 0x3e
	{ "CB RRCA", 0, 8 },                         // 0x3f
	{ "CB NOP", 0, 8 },                           // 0x40
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0x41
	{ "CB LD (BC), A", 0, 8 },               // 0x42
	{ "CB INC BC", 0, 8 },                     // 0x43
	{ "CB INC B", 0, 8 },                       // 0x44
	{ "CB DEC B", 0, 8 },                       // 0x45
	{ "CB LD B, 0x%02X", 0, 16 },               // 0x46
	{ "CB RLCA", 0, 8 },                         // 0x47
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0x48
	{ "CB ADD HL, BC", 0, 8 },              // 0x49
	{ "CB LD A, (BC)", 0, 8 },               // 0x4a
	{ "CB DEC BC", 0, 8 },                     // 0x4b
	{ "CB INC C", 0, 8 },                       // 0x4c
	{ "CB DEC C", 0, 8 },                       // 0x4d
	{ "CB LD C, 0x%02X", 0, 16 },               // 0x4e
	{ "CB RRCA", 0, 8 },                         // 0x4f
	{ "CB NOP", 0, 8 },                           // 0x50
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0x51
	{ "CB LD (BC), A", 0, 8 },               // 0x52
	{ "CB INC BC", 0, 8 },                     // 0x53
	{ "CB INC B", 0, 8 },                       // 0x54
	{ "CB DEC B", 0, 8 },                       // 0x55
	{ "CB LD B, 0x%02X", 0, 16 },               // 0x56
	{ "CB RLCA", 0, 8 },                         // 0x57
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0x58
	{ "CB ADD HL, BC", 0, 8 },              // 0x59
	{ "CB LD A, (BC)", 0, 8 },               // 0x5a
	{ "CB DEC BC", 0, 8 },                     // 0x5b
	{ "CB INC C", 0, 8 },                       // 0x5c
	{ "CB DEC C", 0, 8 },                       // 0x5d
	{ "CB LD C, 0x%02X", 0, 16 },               // 0x5e
	{ "CB RRCA", 0, 8 },                         // 0x5f
	{ "CB NOP", 0, 8 },                           // 0x60
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0x61
	{ "CB LD (BC), A", 0, 8 },               // 0x62
	{ "CB INC BC", 0, 8 },                     // 0x63
	{ "CB INC B", 0, 8 },                       // 0x64
	{ "CB DEC B", 0, 8 },                       // 0x65
	{ "CB LD B, 0x%02X", 0, 16 },               // 0x66
	{ "CB RLCA", 0, 8 },                         // 0x67
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0x68
	{ "CB ADD HL, BC", 0, 8 },              // 0x69
	{ "CB LD A, (BC)", 0, 8 },               // 0x6a
	{ "CB DEC BC", 0, 8 },                     // 0x6b
	{ "CB INC C", 0, 8 },                       // 0x6c
	{ "CB DEC C", 0, 8 },                       // 0x6d
	{ "CB LD C, 0x%02X", 0, 16 },               // 0x6e
	{ "CB RRCA", 0, 8 },                         // 0x6f
	{ "CB NOP", 0, 8 },                           // 0x70
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0x71
	{ "CB LD (BC), A", 0, 8 },               // 0x72
	{ "CB INC BC", 0, 8 },                     // 0x73
	{ "CB INC B", 0, 8 },                       // 0x74
	{ "CB DEC B", 0, 8 },                       // 0x75
	{ "CB LD B, 0x%02X", 0, 16 },               // 0x76
	{ "CB RLCA", 0, 8 },                         // 0x77
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0x78
	{ "CB ADD HL, BC", 0, 8 },              // 0x79
	{ "CB LD A, (BC)", 0, 8 },               // 0x7a
	{ "CB DEC BC", 0, 8 },                     // 0x7b
	{ "CB INC C", 0, 8 },                       // 0x7c
	{ "CB DEC C", 0, 8 },                       // 0x7d
	{ "CB LD C, 0x%02X", 0, 16 },               // 0x7e
	{ "CB RRCA", 0, 8 },                         // 0x7f
	{ "CB NOP", 0, 8 },                           // 0x80
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0x81
	{ "CB LD (BC), A", 0, 8 },               // 0x82
	{ "CB INC BC", 0, 8 },                     // 0x83
	{ "CB INC B", 0, 8 },                       // 0x84
	{ "CB DEC B", 0, 8 },                       // 0x85
	{ "CB LD B, 0x%02X", 0, 16 },               // 0x86
	{ "CB RLCA", 0, 8 },                         // 0x87
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0x88
	{ "CB ADD HL, BC", 0, 8 },              // 0x89
	{ "CB LD A, (BC)", 0, 8 },               // 0x8a
	{ "CB DEC BC", 0, 8 },                     // 0x8b
	{ "CB INC C", 0, 8 },                       // 0x8c
	{ "CB DEC C", 0, 8 },                       // 0x8d
	{ "CB LD C, 0x%02X", 0, 16 },               // 0x8e
	{ "CB RRCA", 0, 8 },                         // 0x8f
	{ "CB NOP", 0, 8 },                           // 0x90
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0x91
	{ "CB LD (BC), A", 0, 8 },               // 0x92
	{ "CB INC BC", 0, 8 },                     // 0x93
	{ "CB INC B", 0, 8 },                       // 0x94
	{ "CB DEC B", 0, 8 },                       // 0x95
	{ "CB LD B, 0x%02X", 0, 16 },               // 0x96
	{ "CB RLCA", 0, 8 },                         // 0x97
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0x98
	{ "CB ADD HL, BC", 0, 8 },              // 0x99
	{ "CB LD A, (BC)", 0, 8 },               // 0x9a
	{ "CB DEC BC", 0, 8 },                     // 0x9b
	{ "CB INC C", 0, 8 },                       // 0x9c
	{ "CB DEC C", 0, 8 },                       // 0x9d
	{ "CB LD C, 0x%02X", 0, 16 },               // 0x9e
	{ "CB RRCA", 0, 8 },                         // 0x9f
	{ "CB NOP", 0, 8 },                           // 0xa0
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0xa1
	{ "CB LD (BC), A", 0, 8 },               // 0xa2
	{ "CB INC BC", 0, 8 },                     // 0xa3
	{ "CB INC B", 0, 8 },                       // 0xa4
	{ "CB DEC B", 0, 8 },                       // 0xa5
	{ "CB LD B, 0x%02X", 0, 16 },               // 0xa6
	{ "CB RLCA", 0, 8 },                         // 0xa7
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0xa8
	{ "CB ADD HL, BC", 0, 8 },              // 0xa9
	{ "CB LD A, (BC)", 0, 8 },               // 0xaa
	{ "CB DEC BC", 0, 8 },                     // 0xab
	{ "CB INC C", 0, 8 },                       // 0xac
	{ "CB DEC C", 0, 8 },                       // 0xad
	{ "CB LD C, 0x%02X", 0, 16 },               // 0xae
	{ "CB RRCA", 0, 8 },                         // 0xaf
	{ "CB NOP", 0, 8 },                           // 0xb0
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0xb1
	{ "CB LD (BC), A", 0, 8 },               // 0xb2
	{ "CB INC BC", 0, 8 },                     // 0xb3
	{ "CB INC B", 0, 8 },                       // 0xb4
	{ "CB DEC B", 0, 8 },                       // 0xb5
	{ "CB LD B, 0x%02X", 0, 16 },               // 0xb6
	{ "CB RLCA", 0, 8 },                         // 0xb7
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0xb8
	{ "CB ADD HL, BC", 0, 8 },              // 0xb9
	{ "CB LD A, (BC)", 0, 8 },               // 0xba
	{ "CB DEC BC", 0, 8 },                     // 0xbb
	{ "CB INC C", 0, 8 },                       // 0xbc
	{ "CB DEC C", 0, 8 },                       // 0xbd
	{ "CB LD C, 0x%02X", 0, 16 },               // 0xbe
	{ "CB RRCA", 0, 8 },                         // 0xbf
	{ "CB NOP", 0, 8 },                           // 0xc0
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0xc1
	{ "CB LD (BC), A", 0, 8 },               // 0xc2
	{ "CB INC BC", 0, 8 },                     // 0xc3
	{ "CB INC B", 0, 8 },                       // 0xc4
	{ "CB DEC B", 0, 8 },                       // 0xc5
	{ "CB LD B, 0x%02X", 0, 16 },               // 0xc6
	{ "CB RLCA", 0, 8 },                         // 0xc7
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0xc8
	{ "CB ADD HL, BC", 0, 8 },              // 0xc9
	{ "CB LD A, (BC)", 0, 8 },               // 0xca
	{ "CB DEC BC", 0, 8 },                     // 0xcb
	{ "CB INC C", 0, 8 },                       // 0xcc
	{ "CB DEC C", 0, 8 },                       // 0xcd
	{ "CB LD C, 0x%02X", 0, 16 },               // 0xce
	{ "CB RRCA", 0, 8 },                         // 0xcf
	{ "CB NOP", 0, 8 },                           // 0xd0
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0xd1
	{ "CB LD (BC), A", 0, 8 },               // 0xd2
	{ "CB INC BC", 0, 8 },                     // 0xd3
	{ "CB INC B", 0, 8 },                       // 0xd4
	{ "CB DEC B", 0, 8 },                       // 0xd5
	{ "CB LD B, 0x%02X", 0, 16 },               // 0xd6
	{ "CB RLCA", 0, 8 },                         // 0xd7
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0xd8
	{ "CB ADD HL, BC", 0, 8 },              // 0xd9
	{ "CB LD A, (BC)", 0, 8 },               // 0xda
	{ "CB DEC BC", 0, 8 },                     // 0xdb
	{ "CB INC C", 0, 8 },                       // 0xdc
	{ "CB DEC C", 0, 8 },                       // 0xdd
	{ "CB LD C, 0x%02X", 0, 16 },               // 0xde
	{ "CB RRCA", 0, 8 },                         // 0xdf
	{ "CB NOP", 0, 8 },                           // 0xe0
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0xe1
	{ "CB LD (BC), A", 0, 8 },               // 0xe2
	{ "CB INC BC", 0, 8 },                     // 0xe3
	{ "CB INC B", 0, 8 },                       // 0xe4
	{ "CB DEC B", 0, 8 },                       // 0xe5
	{ "CB LD B, 0x%02X", 0, 16 },               // 0xe6
	{ "CB RLCA", 0, 8 },                         // 0xe7
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0xe8
	{ "CB ADD HL, BC", 0, 8 },              // 0xe9
	{ "CB LD A, (BC)", 0, 8 },               // 0xea
	{ "CB DEC BC", 0, 8 },                     // 0xeb
	{ "CB INC C", 0, 8 },                       // 0xec
	{ "CB DEC C", 0, 8 },                       // 0xed
	{ "CB LD C, 0x%02X", 0, 16 },               // 0xee
	{ "CB RRCA", 0, 8 },                         // 0xef
	{ "CB NOP", 0, 8 },                           // 0xf0
	{ "CB LD BC, 0x%04X", 0, 8 },            // 0xf1
	{ "CB LD (BC), A", 0, 8 },               // 0xf2
	{ "CB INC BC", 0, 8 },                     // 0xf3
	{ "CB INC B", 0, 8 },                       // 0xf4
	{ "CB DEC B", 0, 8 },                       // 0xf5
	{ "CB LD B, 0x%02X", 0, 16 },               // 0xf6
	{ "CB RLCA", 0, 8 },                         // 0xf7
	{ "CB LD (0x%04X), SP", 0, 8 },         // 0xf8
	{ "CB ADD HL, BC", 0, 8 },              // 0xf9
	{ "CB LD A, (BC)", 0, 8 },               // 0xfa
	{ "CB DEC BC", 0, 8 },                     // 0xfb
	{ "CB INC C", 0, 8 },                       // 0xfc
	{ "CB DEC C", 0, 8 },                       // 0xfd
	{ "CB LD C, 0x%02X", 0, 16 },               // 0xfe
	{ "CB RRCA", 0, 8 },                         // 0xff
];