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

    // Model Data
    vertices := Vertex.[
        // lower right tri
        .{pos = .{ -1.0, -1.0, 0.0}, uv = .{0.0, 0.0}},
        .{pos = .{  1.0, -1.0, 0.0}, uv = .{1.0, 0.0}},
        .{pos = .{  1.0,  1.0, 0.0},  uv = .{1.0, 1.0}},
        // upper left tri
        .{pos = .{  1.0,  1.0, 0.0},  uv = .{1.0, 1.0}},
        .{pos = .{  -1.0,  1.0, 0.0},  uv = .{0.0, 1.0}},
        .{pos = .{ -1.0, -1.0, 0.0}, uv = .{0.0, 0.0}}
    ];
    quad := Model.{ position = .{0.0, 0.0, 0.0}};
    for vertices array_add(*quad.vertices, it);

    quad2 := Model.{position = .{0.0, 0.0, 0.0}};
    for vertices {
        vertex := it;
        vertex.pos.x += 1.0;
        vertex.pos.y += 1.0;        
        array_add(*quad.vertices, vertex);
    }

    // Add a nice texture to the model
    quad.textureID = RegisterTexture("assets/textures/wood_planks_01.tga");
    modelID := RegisterModel(*quad);
    quad2.textureID = RegisterTexture("assets/textures/wood_planks_01.tga");
    model2ID := RegisterModel(*quad2);

    refdef.camera = Camera.{pos = .{0.0, 0.0, 2.0}}; // Move cam 'back' a little bit (+z comes out of the monit... OUCH!)

    // Set GL state
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glFrontFace(GL_CCW);
    glEnable(GL_DEPTH_TEST);

    running := true;
    while running {

        // SDL Event Loop
        event : SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == {
                case SDL_QUIT;
                    running = false;
                case SDL_KEYDOWN;
                    if event.key.keysym.sym == SDLK_ESCAPE running = false;
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