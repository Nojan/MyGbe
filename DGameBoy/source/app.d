import std.stdio;
import derelict.sdl2.sdl;
import emu;

void fatal_error_if(Cond,Args...)(Cond cond, string format, Args args) {
    import std.c.stdlib;
	if(!!cond) {
        stderr.writefln(format,args);
        exit(1);
    }
}

void main()
{
	auto libSDLName = "external\\SDL2\\lib\\x86\\SDL2.dll";
	DerelictSDL2.load(libSDLName);
	writeln("Edit source/app.d to start your project.");

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
	

	bool run = true;
	Emu emu;
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
		
		SDL_RenderPresent(renderer);
	}

	SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    writeln("If we got to this point everything went alright...");
}
