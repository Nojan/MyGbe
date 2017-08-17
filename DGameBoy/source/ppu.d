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
        u8 status = mem.readU8(mem.STAT);
        immutable bool isEnable = bitop.test(status,7);
        if(false && !isEnable)
        {
            scanLineCounter = 0;
            mem.writeU8(mem.LY, 0);
            status &= 252;
            status = bitop.set(status, 0);
            mem.writeU8(mem.STAT, status);
            return;
        }
        u8 currentline = mem.readU8(mem.LY);
        immutable u8 currentmode = status & 0x3;
        u8 mode = currentmode;

        enum : u8 { MODE_HBLANK = 0, MODE_VBLANK = 1, MODE_OAM = 2, MODE_VRAM = 3, }

        bool reqInt = false;
        scanLineCounter += cycleCount;
        if(MODE_HBLANK == currentmode) 
        {
            if(204 <= scanLineCounter)
            {
                currentline++;
                if(143 == currentline) 
                {
					mode = MODE_VBLANK;
                    m_renderDelegate(lcd);
				}
				else 
                    mode = MODE_OAM;
                scanLineCounter -= 204;
            }
        }
        else if(MODE_VBLANK == currentmode) 
        {
            if(456 <= scanLineCounter)
            {
                currentline++;
                if(153 < currentline) 
                {
					currentline = 0;
                    mode = MODE_OAM;
				}
                scanLineCounter -= 456;
            }
        }
        else if(MODE_OAM == currentmode) 
        {
            if(80 <= scanLineCounter)
            {
                mode = MODE_VRAM;
                scanLineCounter -= 80;
            }
        }
        else if(MODE_VRAM == currentmode) 
        {
            if(172 <= scanLineCounter)
            {
                mode = MODE_HBLANK;
                scanLineCounter -= 172;
                DrawScanLine(mem, currentline, status);
            }
        }

        if(currentmode != mode)
        {
            if(MODE_HBLANK == mode)
            {
                status = bitop.reset(status, 1);
                status = bitop.reset(status, 0);
                reqInt = bitop.test(status, 3);
            }
            else if(MODE_VBLANK == mode)
            {
                status = bitop.set(status, 0);
                status = bitop.reset(status, 1);
                reqInt = true; //bitop.test(status, 4);
            }
            else if(MODE_OAM == mode)
            {
                status = bitop.set(status, 1);
                status = bitop.reset(status, 0);
                reqInt = bitop.test(status, 5);
            }
            else if(MODE_VRAM == mode)
            {
                status = bitop.set(status, 1);
                status = bitop.set(status, 0);
            }
            
            if(reqInt && MODE_VBLANK == mode)
            {
                RequestInterupt(mem, 0);
            }
        }

        // check the conincidence flag
        if (false && currentline == mem.readU8(mem.LYC))
        {
            status = bitop.set(status, 2);
            if (bitop.test(status, 6))
                RequestInterupt(mem, 1);
        }
        else
        {
            status = bitop.reset(status, 2);
        }
        mem.writeU8(mem.STAT, status);
        mem.mem[mem.LY] = currentline;
    }

    void delegate(const u8[]) m_renderDelegate;

private:
    pure nothrow @nogc
    void RequestInterupt(ref Memory mem, u8 idx)
    {
        u8 flag = mem.readU8(mem.IF);
        flag = bitop.set(flag, idx);
        mem.writeU8(mem.IF, flag);
    }

    void DrawScanLine(ref Memory mem, immutable u8 currentline, immutable u8 status)
    {
        assert(currentline < lcd_height);
        if (bitop.test(status, 0))
            RenderTiles(mem, currentline, status);
        
         if (bitop.test(status, 1))
            RenderSprites(mem, currentline, status);
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
            tileData = 0x8800 ;
            unsig = false ;
        }

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

        immutable u8 palette = mem.readU8(mem.BGP);

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
            u8 colourNum = bitop.val(data2, colourBit) ;
            colourNum <<= 1;
            colourNum |= bitop.val(data1, colourBit) ;

            u8 colorValue = GetColourFromPalette(colourNum, palette);

            lcd[currentlineoffset + pixel] = colorValue;
        }
    }

    void RenderSprites(ref Memory mem, immutable u8 currentline, immutable u8 status)
    {
        const bool use8x16 = bitop.test(status,2);
        const u16 currentlineoffset = cast(u16)(currentline * lcd_width);
        for (u8 sprite = 0 ; sprite < 40; sprite++)
        {
            // sprite occupies 4 u8s in the sprite attributes table
            const u8 index = cast(u8)(sprite*4);
            const u8 yPos = cast(u8)(mem.readU8(0xFE00+index) - 16);
            const u8 xPos = cast(u8)(mem.readU8(0xFE00+index+1)-8);
            const u8 tileLocation = mem.readU8(0xFE00+index+2) ;
            const u8 attributes = mem.readU8(0xFE00+index+3) ;

            bool yFlip = bitop.test(attributes,6) ;
            bool xFlip = bitop.test(attributes,5) ;

            int scanline = mem.readU8(0xFF44);

            int ysize = 8;
            if (use8x16)
                ysize = 16;

            // does this sprite intercept with the scanline?
            if ((scanline >= yPos) && (scanline < (yPos+ysize)))
            {
                int line = scanline - yPos ;

                // read the sprite in backwards in the y axis
                if (yFlip)
                {
                    line -= ysize ;
                    line *= -1 ;
                }

                line *= 2; // same as for tiles
                u16 dataAddress = cast(u16)((0x8000 + (tileLocation * 16)) + line);
                u8 data1 = mem.readU8( dataAddress ) ;
                u8 data2 = mem.readU8( cast(u16)(dataAddress +1) ) ;

                // its easier to read in from right to left as pixel 0 is
                // bit 7 in the colour data, pixel 1 is bit 6 etc...
                for (u8 tilePixel = 7; tilePixel < 7; tilePixel--)
                {
                    u8 colourbit = tilePixel ;
                    // read the sprite in backwards for the x axis
                    if (xFlip)
                    {
                        colourbit -= 7 ;
                        colourbit *= -1 ;
                    }

                    // the rest is the same as for tiles
                    u8 colourNum = bitop.val(data2, colourbit) ;
                    colourNum <<= 1;
                    colourNum |= bitop.val(data1, colourbit) ;

                    u16 colourAddress = bitop.test(attributes,4) ? 0xFF49 : 0xFF48;
                    const u8 palette = mem.readU8(colourAddress);
                    const u8 colorValue = GetColourFromPalette(colourNum, palette) ;

                    // white is transparent for sprites.
                    if (colorValue == 0)
                        continue;

                    int xPix = 0 - tilePixel ;
                    xPix += 7 ;

                    int pixel = xPos+xPix ;

                    lcd[currentlineoffset + pixel] = colorValue;
                }
            }
        }
    }

    u8 GetColourFromPalette(u8 colourIdx, u8 palette)
    {
        assert(colourIdx < 4);
        u8 hi, lo;
        final switch(colourIdx)
        {
            case 0: hi = 1; lo = 0; break;
            case 1: hi = 3; lo = 2; break;
            case 2: hi = 5; lo = 4; break;
            case 3: hi = 7; lo = 6; break;
        }
        const int colour = (bitop.val(palette, hi) << 1) | bitop.val(palette, lo);
        return cast(u8)colour;
    }
public:
    i16 scanLineCounter = 0;
    immutable u16 lcd_height = 144;
    immutable u16 lcd_width = 160;
    u8[lcd_width*lcd_height] lcd;

version(TileWindow)
{
    immutable int tile_size = 8;
    immutable u16 tile_height = 0x18 * tile_size;
    immutable u16 tile_width = 0x10 * tile_size;
    u8[tile_width*tile_height] tile_debug;

    void DrawTile(ref Memory mem, u16 tileX, u16 tileY)
    {
        immutable u16 beginAddress = cast(u16)(0x8000 + tileY*0x100 + tileX*0x10);
        immutable u16 endAddress = cast(u16)(beginAddress + (tile_size * 2));
        immutable u8 palette = mem.readU8(mem.BGP);
        immutable u16 destXAddressBegin = cast(u16)(tileX * tile_size);
        u16 destXAddress = destXAddressBegin;
        u16 destYAddress = cast(u16)(tileY * tile_size);

        for(u16 pixLineAddress = beginAddress; pixLineAddress < endAddress; pixLineAddress += 2)
        {
            const u8 data1 = mem.readU8(cast(u16)(pixLineAddress+0));
            const u8 data2 = mem.readU8(cast(u16)(pixLineAddress+1));
            for(u8 pix = 7; pix <= 7; --pix, destXAddress++)
            {
                u8 colourNum = bitop.val(data2, pix) ;
                colourNum <<= 1;
                colourNum |= bitop.val(data1, pix) ;
                const u8 colorValue = GetColourFromPalette(colourNum, palette);
                const u16 destAddress = cast(u16)(destYAddress*tile_width + destXAddress);
                tile_debug[destAddress] = colorValue;
            }
            destXAddress = destXAddressBegin;
            destYAddress++;
        }
    }

    void OutputTiles(ref Memory mem) {
        immutable u16 beginAddress = 0x8000;
        immutable u16 endAddress = 0x97F0;
        immutable u8 palette = mem.readU8(mem.BGP);
        u16 destXAddress = 0;
        u16 destYAddress = 0;
        
        // for(u16 pixLineAddress = beginAddress; pixLineAddress < (beginAddress + (tile_size * 2)); pixLineAddress += 2)
        // {
        //     const u8 data1 = mem.readU8(cast(u16)(pixLineAddress+0));
        //     const u8 data2 = mem.readU8(cast(u16)(pixLineAddress+1));
        //     for(u8 pix = 0; pix < 8; ++pix)
        //     {
        //         u8 colourNum = bitop.val(data2, pix) ;
        //         colourNum <<= 1;
        //         colourNum |= bitop.val(data1, pix) ;
        //         const u8 colorValue = GetColourFromPalette(colourNum, palette);
        //         const u16 destAddress = cast(u16)(destYAddress*tile_width + destXAddress);
        //         tile_debug[destAddress] = colorValue;
        //         destXAddress++;
        //         if(8 <= destXAddress) 
        //         {
        //             destXAddress = 0;
        //             destYAddress++;
        //         }
        //     }
        // }

        for(u16 idY = 0; idY < 0x18; ++idY)
        {
            for(u16 idX = 0; idX < 0x10; ++idX)
            {
                DrawTile(mem,idX,idY);
            }
        }

        m_tileRenderDelegate(tile_debug);
    }
    void SetTileRenderDelegate(void delegate(const u8[]) render)
    {
        m_tileRenderDelegate = render;
    }
    void delegate(const u8[]) m_tileRenderDelegate;
}
}