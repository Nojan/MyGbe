// dub build -b=debug --arch=x86_64
import std.stdio;
import derelict.sdl2.sdl;
import emu;
import numeric_alias;

void fatal_error_if(Cond,Args...)(Cond cond, string format, Args args) {
    import std.c.stdlib;
	if(!!cond) {
        stderr.writefln(format,args);
        exit(1);
    }
}

void main(string[] args)
{
	auto libSDLName = "external\\SDL2\\lib\\x64\\SDL2.dll";
	DerelictSDL2.load(libSDLName);

    fatal_error_if(SDL_Init(SDL_INIT_VIDEO), "Failed to initialize sdl!");

    auto window = SDL_CreateWindow(
            "An SDL2 window",
            SDL_WINDOWPOS_UNDEFINED,
            SDL_WINDOWPOS_UNDEFINED,
            800,
            600,
            SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
    fatal_error_if(window is null,"Failed to create SDL window!");

    auto renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_PRESENTVSYNC);
    auto texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, 144, 160);

    version(TileWindow)
    {
        immutable int TileSize = 8;
        immutable int windowTileWidth = 0x10 * TileSize;
        immutable int windowTileHeight = 0x18 * TileSize;
        auto windowTile = SDL_CreateWindow(
        "TileWindow",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
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
            final switch(lcd_pixel)
            {
                case 0:
                pixels[idx] = 0;
                break;
                case 1:
                pixels[idx] = 0x00777777;
                break;
                case 2:
                pixels[idx] = 0x00CCCCCC;
                break;
                case 3:
                pixels[idx] = 0x00FFFFFF;
                break;
            }
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
            final switch(lcd_pixel)
            {
                case 0:
                pixels[idx] = 0;
                break;
                case 1:
                pixels[idx] = 0x00777777;
                break;
                case 2:
                pixels[idx] = 0x00CCCCCC;
                break;
                case 3:
                pixels[idx] = 0x00FFFFFF;
                break;
            }
        }
        SDL_UpdateTexture(textureTile, null, pixels.ptr, windowTileWidth * u32.sizeof);
        SDL_RenderClear(rendererTile);
        SDL_RenderCopy(rendererTile, textureTile, null, null);
        SDL_RenderPresent(rendererTile);
    }
    emu.SetTileRenderDelegate(&TileRenderFunction);
}

	while(run) {
		SDL_Event event;
        while(SDL_PollEvent(&event))
        {
			switch(event.type)
            {
            case SDL_QUIT:
                run = 0;
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
