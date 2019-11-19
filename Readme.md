# Gameboy emulator
This is a [GameBoy](https://en.wikipedia.org/wiki/Game_Boy) emulator written in [D](https://dlang.org/). 
It is a learning project, hence do not assume this great D code.

While sound is not implemented, you can play any cartridge that does not use an MBC, such as simple games or homebrews. You can try [Snake](https://gbhh.avivace.com/game/snake-gb).

I tested the emulator with test roms. According to this [website](https://gbdev.gg8.se/wiki/articles/Test_ROMs), one does not need to pass all tests to have a good emulator, it is just easier to make sure it is accurate rather than hunt weird bugs inside a specific game.

CPU instructions test
- [x] 01-special
- [ ] 02-interrupts
- [x] 03-op sp,hl
- [x] 04-op r,imm
- [x] 05-op rp
- [x] 06-ld r,r
- [x] 07-jr,jp,call,ret,rst
- [x] 08-misc instrs
- [ ] 09-op r,r
- [x] 10-bit ops
- [x] 11-op a,(hl)

# Dependencies
SDL2. The program will fail if it cannot find it.
