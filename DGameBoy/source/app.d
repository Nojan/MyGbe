// dub build -b=debug --arch=x86_64
import std.stdio;
import derelict.sdl2.sdl;
import emu;
import numeric_alias;

void fatal_error_if(Cond,Args...)(Cond cond, string format, Args args) {
    import core.stdc.stdlib;
	if(!!cond) {
        stderr.writefln(format,args);
        exit(1);
    }
}

u32 pix2color(const u8 pixel)
{
    u32 result;
    final switch(pixel)
    {
        case 3:
        result = 0;
        break;
        case 2:
        result = 0x00777777;
        break;
        case 1:
        result = 0x00CCCCCC;
        break;
        case 0:
        result = 0x00FFFFFF;
        break;
    }
    return result;
}

void main(string[] args)
{
	DerelictSDL2.load();

    fatal_error_if(SDL_Init(SDL_INIT_VIDEO), "Failed to initialize sdl!");

    auto window = SDL_CreateWindow(
            "An SDL2 window",
            15,
            25,
            800,
            600,
            SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
    fatal_error_if(window is null,"Failed to create SDL window!");

    auto renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_PRESENTVSYNC);
    auto texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, 160, 144);

    version(TileWindow)
    {
        immutable int TileSize = 8;
        immutable int windowTileWidth = 0x10 * TileSize;
        immutable int windowTileHeight = 0x18 * TileSize;
        auto windowTile = SDL_CreateWindow(
        "TileWindow",
        15,
        675,
        windowTileWidth,
        windowTileHeight,
        SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
        fatal_error_if(windowTile is null,"Failed to create SDL window!");

        auto rendererTile = SDL_CreateRenderer(windowTile, -1, SDL_RENDERER_PRESENTVSYNC);
        auto textureTile = SDL_CreateTexture(rendererTile, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, windowTileWidth, windowTileHeight);
    }
	
	bool run = true;
	Emu emu;
    if(1 < args.length) {
        import std.stdio;
        const string filename = args[1];
        writeln("Loading " ~ filename);
        import std.file;
        fatal_error_if(!exists(filename), filename ~ " doesn't exist."); 
        File rom = File(filename, "rb");
        immutable ulong romSize = rom.size();
        rom.rawRead(emu.MemoryCart());
        emu.Reset();
    }

    void RenderFunction(const u8[] lcd)
    {
        u32[144*160] pixels;
        for(int idx = 0; idx<lcd.length; ++idx )
        {
            const u8 lcd_pixel = lcd[idx];
            pixels[idx] = pix2color(lcd_pixel);
        }
        SDL_UpdateTexture(texture, null, pixels.ptr, 160 * u32.sizeof);
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, null, null);
        SDL_RenderPresent(renderer);
    }
    emu.SetRenderDelegate(&RenderFunction);
version(TileWindow)
{
    void TileRenderFunction(const u8[] tiles)
    {
        u32[windowTileWidth*windowTileHeight] pixels;
        for(int idx = 0; idx<tiles.length; ++idx )
        {
            const u8 lcd_pixel = tiles[idx];
            pixels[idx] = pix2color(lcd_pixel);
        }
        SDL_UpdateTexture(textureTile, null, pixels.ptr, windowTileWidth * u32.sizeof);
        SDL_RenderClear(rendererTile);
        SDL_RenderCopy(rendererTile, textureTile, null, null);
        SDL_RenderPresent(rendererTile);
    }
    emu.SetTileRenderDelegate(&TileRenderFunction);
}

    version(BGWindow)
    {
        immutable int BGTileSize = 8;
        immutable int windowBGWidth = 32 * BGTileSize;
        immutable int windowBGHeight = 32 * BGTileSize;
        auto windowBG = SDL_CreateWindow(
        "BGWindow",
        175,
        675,
        windowBGWidth,
        windowBGHeight,
        SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
        fatal_error_if(windowTile is null,"Failed to create SDL window!");

        auto rendererBG = SDL_CreateRenderer(windowBG, -1, SDL_RENDERER_PRESENTVSYNC);
        auto textureBG = SDL_CreateTexture(rendererBG, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, windowBGWidth, windowBGHeight);

        void BGRenderFunction(const u8[] bg)
        {
            u32[windowBGWidth*windowBGHeight] pixels;
            for(int idx = 0; idx<bg.length; ++idx )
            {
                const u8 lcd_pixel = bg[idx];
                pixels[idx] = pix2color(lcd_pixel);
            }
            SDL_UpdateTexture(textureBG, null, pixels.ptr, windowBGWidth * u32.sizeof);
            SDL_RenderClear(rendererBG);
            SDL_RenderCopy(rendererBG, textureBG, null, null);
            SDL_RenderPresent(rendererBG);
        }
        emu.SetBGRenderDelegate(&BGRenderFunction);
    }

	while(run) {
		SDL_Event event;
        while(SDL_PollEvent(&event))
        {
			switch(event.type)
            {
            case SDL_QUIT:
                run = false;
                break;
            case SDL_KEYDOWN: 
            case SDL_KEYUP:
                {
                    const SDL_Keycode key = event.key.keysym.sym;
                    const bool pressed = !(SDL_PRESSED == event.key.state);
                    switch(key)
                    {
                        case SDLK_LEFT:
                            emu.GetKeys().left = pressed;
                            break;
                        case SDLK_RIGHT:
                            emu.GetKeys().right = pressed;
                            break;
                        case SDLK_UP:
                            emu.GetKeys().up = pressed;
                            break;
                        case SDLK_DOWN:
                            emu.GetKeys().down = pressed;
                            break;
                        case SDLK_a:
                            emu.GetKeys().a = pressed;
                            break;
                        case SDLK_s:
                            emu.GetKeys().b = pressed;
                            break;
                        case SDLK_BACKSPACE:
                            emu.GetKeys().select = pressed;
                            break;
                        case SDLK_RETURN:
                            emu.GetKeys().start = pressed;
                            break;
                        default:
                            break;
                    }
                }
                break;
			default:
                break;
			}
		}

		emu.Frame();
	}

	SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    version(TileWindow)
    {
        SDL_DestroyRenderer(rendererTile);
        SDL_DestroyWindow(windowTile);
    }
    SDL_Quit();
}
