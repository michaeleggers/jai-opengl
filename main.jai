#import "Basic";
#import "SDL";
#import "GL";
#import "File";
#import "Math";

#load "model.jai";
#load "textures.jai";
#load "render.jai";
#load "camera.jai";
#load "mapparser.jai";
#load "graphics_math.jai";
#load "geometry.jai";

AllocString :: (count : u32) -> string {
    s : string;
    s.count = count;
    s.data = alloc(count);

    return s;
}

ToCString :: (s : string) -> *u8 {
    result := cast(*u8)alloc(s.count + 1); // +1 for null-byte
    memcpy(result, s.data, s.count);
    result[s.count] = 0;    

    return result;
}

main :: () {

    if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
        print("SDL Init Error: %\n", to_string(SDL_GetError()));
        return;
    }

    RenderPrepare();

    refdef : RefDef;

    refdef.window = SDL_CreateWindow("Jai SDL-OpenGL",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        xx refdef.clientWidth, xx refdef.clientHeight,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);

    if (!refdef.window) {
        print("SDL CreateWindow Error: %\n", to_string(SDL_GetError()));
        return;
    }
    
    sdlGlContext := SDL_GL_CreateContext(refdef.window);
    if (!sdlGlContext) {
        print("SDL GL_CreateContext Error: %\n", to_string(SDL_GetError()));
        return;
    }

    gl_load(*gl, SDL_GL_GetProcAddress);
    using gl;

    print("GL Vendor = %\n", to_string(glGetString(GL_VENDOR)));
    print("GL Version = %\n", to_string(glGetString(GL_VERSION)));

    RenderInit();

    brushes := LoadMapFile("assets/maps/starter.map");
    world := Model.{ position = .{0.0, 0.0, 0.0}};
    for brush : brushes {        
        for vertex : GEOM_UNIT_CUBE {
            vert := vertex;
            vert.pos.x += brush.xPos;
            vert.pos.y += brush.yPos;
            vert.pos.z += brush.zPos;
            array_add(*world.vertices, vert);
        }
    }

    // Add a nice texture to the model
    world.textureID = RegisterTexture("assets/textures/wood_planks_01.tga");
    modelID := RegisterModel(*world);

    refdef.camera = CreateCamera(.{ pos = .{-1.5, 5.2, 6.5}, fov = 50.0 }); // Move cam 'back' a little bit (+z comes out of the monit... OUCH!)

    running := true;
    while running {

        // SDL Event Loop
        event : SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == {
                case SDL_QUIT;
                    running = false;
                    
                case SDL_KEYDOWN;
                    if event.key.keysym.sym == SDLK_ESCAPE  running = false;
                    if event.key.keysym.sym == SDLK_RIGHT   RotateAroundUp(*refdef.camera, -0.01);
                    if event.key.keysym.sym == SDLK_LEFT    RotateAroundUp(*refdef.camera,  0.01);
                    if event.key.keysym.sym == SDLK_UP      RotateAroundSide(*refdef.camera,  0.01);
                    if event.key.keysym.sym == SDLK_DOWN    RotateAroundSide(*refdef.camera, -0.01);
                    if event.key.keysym.sym == SDLK_d       MoveSide(*refdef.camera,  0.1);
                    if event.key.keysym.sym == SDLK_a       MoveSide(*refdef.camera, -0.1);
                    if event.key.keysym.sym == SDLK_w       MoveForward(*refdef.camera,  0.1);
                    if event.key.keysym.sym == SDLK_s       MoveForward(*refdef.camera, -0.1);

                case SDL_WINDOWEVENT;
                    if event.window.event == SDL_WINDOWEVENT_RESIZED {
                        refdef.clientWidth = xx event.window.data1;
                        refdef.clientHeight = xx event.window.data2;
                        print("Window client dimensions have changed: ( %, % )\n", refdef.clientWidth, refdef.clientHeight);
                    }                    

            }
        }

        DrawFrame(refdef);
    }

    SDL_DestroyWindow(refdef.window);
    SDL_Quit();

}