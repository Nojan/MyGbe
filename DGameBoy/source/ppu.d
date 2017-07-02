import numeric_alias;
import memory;
import bitop;

struct PPU {
    void SetRenderDelegate(void delegate(const u8[]) render)
    {
        m_renderDelegate = render;
    }
    
    void Step(i16 cycleCount, ref Memory mem) 
    {
        u8 status = mem.readU8(mem.LCDC);
        immutable bool isEnable = bitop.test(status,7);
        if(!isEnable)
        {
            scanLineCounter = 456;
            mem.writeU8(mem.SCNL, 0);
            status &= 252;
            status = bitop.set(status, 0);
            mem.writeU8(mem.LCDS, status);
            return;
        }
        u8 currentline = mem.readU8(mem.SCNL);
        immutable u8 currentmode = status & 0x3;
        u8 mode = 0;
        bool reqInt = false; 
        if (currentline >= 144)
        {      
            mode = 1;
            status = bitop.set(status, 0);
            status = bitop.reset(status, 1);
            reqInt = bitop.test(status, 4);
        }
        else
        {
            immutable int mode2bounds = 456-80;
            immutable int mode3bounds = mode2bounds - 172;

            // mode 2
            if (scanLineCounter >= mode2bounds)
            {
                mode = 2 ;
                status = bitop.set(status, 1);
                status = bitop.reset(status, 0);
                reqInt = bitop.test(status, 5);
            }
            // mode 3
            else if(scanLineCounter >= mode3bounds)
            {
                mode = 3 ;
                status = bitop.set(status, 1);
                status = bitop.set(status, 0);
            }
            // mode 0
            else
            {
                mode = 0;
                status = bitop.reset(status, 1);
                status = bitop.reset(status, 0);
                reqInt = bitop.test(status, 3);
            }
        }

        // just entered a new mode so request interupt
        if (reqInt && (mode != currentmode))
            RequestInterupt(mem, 1);

        // check the conincidence flag
        if (currentline == mem.readU8(mem.LYC))
        {
            status = bitop.set(status, 2);
            if (bitop.test(status, 6))
                RequestInterupt(mem, 1);
        }
        else
        {
            status = bitop.reset(status, 2);
        }
        mem.writeU8(mem.LCDS, status);

        scanLineCounter -= cycleCount;
        if(scanLineCounter <= 0) 
        {
            currentline++;
            scanLineCounter = 456 ;

            if (currentline == 144)
            {
                RequestInterupt(mem, 0);
                m_renderDelegate(lcd);
            }
            else if (currentline > 153)
            {    
                currentline = 0;
            }
            else if (currentline < 144)
            {
                DrawScanLine(mem, currentline, status);
                m_renderDelegate(lcd);
            }

            mem.mem[mem.SCNL] = currentline;
        }
    }

    void delegate(const u8[]) m_renderDelegate;

private:
    pure nothrow @nogc
    void RequestInterupt(ref Memory mem, u8 idx)
    {
        u8 flag = mem.readU8(mem.IF);
        flag = bitop.set(flag, 0x1);
        mem.writeU8(mem.IF, flag);
    }

    void DrawScanLine(ref Memory mem, immutable u8 currentline, immutable u8 status)
    {
        assert(currentline < lcd_height);
        if (bitop.test(status, 0))
            RenderTiles(mem, currentline, status);
        
         if (bitop.test(status, 1))
            RenderSprites(mem);

        const u8 value = currentline % 2 == 0 ? 1 : 0;
        for(int idx = currentline*lcd_width; idx < (currentline+1)*lcd_width; ++idx)
        {
            lcd[idx] = value;
        }
    }

    void RenderTiles(ref Memory mem, immutable u8 currentline, immutable u8 status)
    {
        u16 tileData = 0;
        u16 backgroundMemory = 0;
        bool unsig = true;

        // where to draw the visual area and the window
        u8 scrollY = mem.readU8(mem.SCY);
        u8 scrollX = mem.readU8(mem.SCX);
        u8 windowY = mem.readU8(mem.WY);
        u8 windowX = cast(u8)(mem.readU8(mem.WX) - 7);

        const bool usingWindow = bitop.test(status,5) && (windowY <= currentline);

        if (bitop.test(status,4))
        {
            tileData = 0x8000 ;
        }
        else
        {
            // IMPORTANT: This memory region uses signed
            // bytes as tile identifiers
            tileData = 0x8800 ;
            unsig = false ;
        }

        // which background mem?
        const u8 backgroundMemBitIndex = usingWindow ? 6 : 3;
        if (bitop.test(status, backgroundMemBitIndex))
            backgroundMemory = 0x9C00;
        else
            backgroundMemory = 0x9800;

        u8 yPos = currentline;
        if (!usingWindow)
            yPos += scrollY;
        else
            yPos = cast(u8)(yPos - windowY);

        u16 tileRow = ((cast(u8)(yPos/8))*32);

        // time to start drawing the 160 horizontal pixels
        // for this scanline
        const u16 currentlineoffset = cast(u16)(currentline * lcd_width);
        for (u16 pixel = 0 ; pixel < lcd_width; pixel++)
        {
            u16 xPos = cast(u16)(pixel+scrollX) ;

            // translate the current x pos to window space if necessary
            if (usingWindow)
            {
                if (pixel >= windowX)
                {
                    xPos = cast(u16)(pixel - windowX);
                }
            }

            // which of the 32 horizontal tiles does this xPos fall within?
            u16 tileCol = (xPos/8);
            i16 tileNum;

            // get the tile identity number. Remember it can be signed
            // or unsigned
            u16 tileAddrss = cast(u16)(backgroundMemory+tileRow+tileCol);
            if(unsig)
                tileNum = cast(u8)mem.readU8(tileAddrss);
            else
                tileNum = cast(i8)mem.readU8(tileAddrss);

            // deduce where this tile identifier is in memory. Remember i
            // shown this algorithm earlier
            u16 tileLocation = tileData ;

            if (unsig)
                tileLocation += (tileNum * 16) ;
            else
                tileLocation += ((tileNum+128) *16) ;

            // find the correct vertical line we're on of the
            // tile to get the tile data
            //from in memory
            u8 line = yPos % 8 ;
            line *= 2; // each vertical line takes up two bytes of memory
            u8 data1 = mem.readU8(cast(u16)(tileLocation + line));
            u8 data2 = mem.readU8(cast(u16)(tileLocation + line + 1));

            // pixel 0 in the tile is it 7 of data 1 and data2.
            // Pixel 1 is bit 6 etc..
            u8 colourBit = xPos % 8 ;
            colourBit -= 7 ;
            colourBit *= -1 ;

            // combine data 2 and data 1 to get the colour id for this pixel
            // in the tile
            int colourNum = bitop.val(data2, colourBit) ;
            colourNum <<= 1;
            colourNum |= bitop.val(data1, colourBit) ;

            // now we have the colour id get the actual
            // colour from palette 0xFF47
            //COLOUR col = GetColour(colourNum, 0xFF47) ;
            u8 colorValue = 2;

            // setup the RGB values
            // switch(col)
            // {
            //     case WHITE: colorValue = 3; break;
            //     case LIGHT_GRAY: colorValue = 2; break ;
            //     case DARK_GRAY: colorValue = 1; break ;
            // }


            lcd[currentlineoffset + pixel] = colorValue;
        }
    }

    void RenderSprites(ref Memory mem)
    {
        
    }

    i16 scanLineCounter;
    immutable u16 lcd_height = 144;
    immutable u16 lcd_width = 160;
    u8[lcd_width*lcd_height] lcd;
}
