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

MouseState :: struct {
    x, y : s32;
    oldX, oldY : s32;
}

keyState : [#run enum_highest_value(SDL_Keycode)] bool;

UpdateCamera :: (camera : *Camera, dX : s32, dY : s32) {
    RotateAroundUp(camera, -dX * 0.01);
    RotateAroundSide(camera, -dY * 0.01);
}

UpdateCameraOnKeys :: (camera : *Camera) {
    if keyState[SDLK_RIGHT]     RotateAroundUp(camera, -0.0001);
    if keyState[SDLK_LEFT]      RotateAroundUp(camera,  0.0001);
    if keyState[SDLK_UP]        RotateAroundSide(camera,  0.0001);
    if keyState[SDLK_DOWN]      RotateAroundSide(camera, -0.0001);
    if keyState[SDLK_d]         MoveSide(camera,  0.01);
    if keyState[SDLK_a]         MoveSide(camera, -0.01);
    if keyState[SDLK_w]         MoveForward(camera,  0.01);
    if keyState[SDLK_s]         MoveForward(camera, -0.01);
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

    // Safe mouse state, so we can get a delta
    mouseState : MouseState;

    running := true;
    while running {

        mouseX, mouseY : s32;
        buttonMask := SDL_GetMouseState(*mouseX, *mouseY);
        mouseState.oldX = mouseX;
        mouseState.oldY = mouseY;

        // SDL Event Loop
        event : SDL_Event;
        while SDL_PollEvent(*event) {

            // Keep for reference: We could also just always poll the state without
            //                     waiting for events to be sent by the os.

            // mouseX, mouseY : s32;
            // buttonMask := SDL_GetMouseState(*mouseX, *mouseY);
            // print("Mouse at %, %\n", mouseX, mouseY);
            // if SDL_BUTTON(buttonMask) & SDL_BUTTON_LEFT == SDL_BUTTON_LEFT {
            //     print("Mouse button down\n");
            //     print("Mouse pressed at %, %\n", mouseX, mouseY);
            // }

            if event.type == {
                case SDL_QUIT;
                    running = false;
                    
                case SDL_KEYDOWN;
                    if event.key.keysym.sym == SDLK_ESCAPE  running = false;
                    if event.key.keysym.sym == SDLK_RIGHT   keyState[SDLK_RIGHT] = true;
                    if event.key.keysym.sym == SDLK_LEFT   keyState[SDLK_LEFT] = true;
                    if event.key.keysym.sym == SDLK_UP   keyState[SDLK_UP] = true;
                    if event.key.keysym.sym == SDLK_DOWN   keyState[SDLK_DOWN] = true;
                    if event.key.keysym.sym == SDLK_d   keyState[SDLK_d] = true;
                    if event.key.keysym.sym == SDLK_a   keyState[SDLK_a] = true;
                    if event.key.keysym.sym == SDLK_w   keyState[SDLK_w] = true;
                    if event.key.keysym.sym == SDLK_s   keyState[SDLK_s] = true;
            
                case SDL_KEYUP;
                    if event.key.keysym.sym == SDLK_RIGHT   keyState[SDLK_RIGHT] = false;
                    if event.key.keysym.sym == SDLK_LEFT   keyState[SDLK_LEFT] = false;
                    if event.key.keysym.sym == SDLK_UP   keyState[SDLK_UP] = false;
                    if event.key.keysym.sym == SDLK_DOWN   keyState[SDLK_DOWN] = false;
                    if event.key.keysym.sym == SDLK_d   keyState[SDLK_d] = false;
                    if event.key.keysym.sym == SDLK_a   keyState[SDLK_a] = false;
                    if event.key.keysym.sym == SDLK_w   keyState[SDLK_w] = false;
                    if event.key.keysym.sym == SDLK_s   keyState[SDLK_s] = false;

                // case SDL_MOUSEBUTTONDOWN;
                //     // if event.button.state == SDL_PRESSED {
                //         print("Mouse button down\n");
                //         mouseX, mouseY : s32;
                //         buttonMask := SDL_GetMouseState(*mouseX, *mouseY);
                //         if SDL_BUTTON(buttonMask) & SDL_BUTTON_LEFT == SDL_BUTTON_LEFT {
                //             print("Mouse pressed at %, %\n", mouseX, mouseY);
                //         }
                //     // }

                case SDL_MOUSEMOTION;
                    mouseX = event.motion.x;
                    mouseY = event.motion.y;
                    if event.motion.state & SDL_BUTTON(3) {
                        dX := mouseX - mouseState.oldX;
                        dY := mouseY - mouseState.oldY;
                        UpdateCamera(*refdef.camera, dX, dY); // TODO: Move this down, out of the event loop
                        print("Mouse delta %, %\n", dX, dY);
                        mouseState.oldX = mouseX;
                        mouseState.oldY = mouseY;
                    }
                
                case SDL_MOUSEBUTTONUP;
                    mouseState.oldX = 0;
                    mouseState.oldY = 0;

                case SDL_WINDOWEVENT;
                    if event.window.event == SDL_WINDOWEVENT_RESIZED {
                        refdef.clientWidth = xx event.window.data1;
                        refdef.clientHeight = xx event.window.data2;
                        print("Window client dimensions have changed: ( %, % )\n", refdef.clientWidth, refdef.clientHeight);
                    }                    

            }
        }

        // Update stuff
        UpdateCameraOnKeys(*refdef.camera);

        // Rendition
        DrawFrame(refdef);
    }

    SDL_DestroyWindow(refdef.window);
    SDL_Quit();

}