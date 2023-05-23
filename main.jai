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
#load "hud.jai";

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

UpdateCameraOnMouse :: (camera : *Camera, dX : s32, dY : s32) {
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

    crosshairHUD := CreateHUD("crosshair_point.png");

    brushes := LoadMapFile("assets/maps/single_brush.map");
    world : [..] Model;
    //world := Model.{ position = .{0.0, 0.0, 0.0}};
    for brush : brushes {
        model : Model;
        model.textureID = RegisterTexture(brush.texture);
        for tri : GEOM_UNIT_CUBE {
            t := tri;
            brushOffset := Vector3.{brush.xPos, brush.yPos, brush.zPos};
            t.a.pos += brushOffset;
            t.b.pos += brushOffset; 
            t.c.pos += brushOffset;
            array_add(*model.tris, t);
        }
        array_add(*world, model);
        RegisterModel(*model);
    }

    // Add a nice texture to the model
    // world.textureID = RegisterTexture("wood_planks_01.tga");
    // modelID := RegisterModel(*world);

    refdef.camera = CreateCamera(.{ pos = .{0.0, 0.0, 5.0}, fov = 50.0 }); // Move cam 'back' a little bit (+z comes out of the monit... OUCH!)

    // Safe mouse state, so we can get a delta
    mouseState : MouseState;

    running := true;
    while running {

        // Maybe even use SDL_GetKeyboardState() here and don't rely on SDL events at all?
        mouseX, mouseY : s32;
        buttonMask := SDL_GetMouseState(*mouseX, *mouseY);
        mouseState.oldX = mouseX;
        mouseState.oldY = mouseY;

        // SDL Event Loop
        event : SDL_Event;
        while SDL_PollEvent(*event) {         

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
                    if event.key.keysym.sym == SDLK_TAB keyState[SDLK_TAB] = !keyState[SDLK_TAB];
            
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
                        UpdateCameraOnMouse(*refdef.camera, dX, dY); // TODO: Move this down, out of the event loop
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
        // Camera    
        UpdateCameraOnKeys(*refdef.camera);

        // Test triangle picking
        worldSpaceXYZ := PickTri(refdef.camera, .{cast(float)mouseX, cast(float)(cast(s32)refdef.clientHeight - mouseY)}, refdef.clientWidth, refdef.clientHeight, world);
        // print("ws x, y : %\n", worldSpaceXYZ);
        viewMat := CreateView(refdef.camera);        

        // Draw a test HUD element
        DrawHUD(*refdef, crosshairHUD, xPos = 0.5, yPos = -.5, scaleX = .2, scaleY = .2);
        DrawHUD(*refdef, crosshairHUD, xPos = -0.5, yPos = .5, scaleX = .1, scaleY = .1);

        // Render settings
        refdef.wireframe = keyState[SDLK_TAB];        

        // Rendition
        DrawFrame(refdef);
    }

    SDL_DestroyWindow(refdef.window);
    SDL_Quit();

}