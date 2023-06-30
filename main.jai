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
#load "base_entity.jai";
#load "entity.jai";
#load "world.jai";
#load "collision.jai";
#load "input.jai";

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
    x, y            : s32;
    oldX, oldY      : s32;
    dX, dY          : s32;
    rightButtonDown  := false;
    rightButtonWentUp := false;
}

keyState : [#run enum_highest_value(SDL_Keycode)] bool;

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

    brushes, entities := LoadMapFile("assets/maps/starter.map");
    // Init world and upload the world geometry to GPU
    world : World;
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
        array_add(*world.models, model);
        RegisterModel(*model); // Upload to GPU
    }
    // Initialize Entities
    SpawnEntities(entities, *refdef, *world);

    // Add a nice texture to the model
    // world.textureID = RegisterTexture("wood_planks_01.tga");
    // modelID := RegisterModel(*world);

    debugCamera := CreateCamera(.{ pos = .{0.0, 0.0, 20.0}, fov = 50.0 }); // Move cam 'back' a little bit (+z comes out of the monit... OUCH!)
    refdef.camera = *debugCamera;
    followCamera := CreateFollowCamera(.{ pos = .{world.player.pos.x, world.player.pos.y + 1, world.player.pos.z + 1}, fov = 50.0 }, *world.player, 10.0);
    world.player.followCamera = *followCamera;
    followCamera2 := FollowCamera.{};
    // refdef.camera = *followCamera;
    print("debugCamera.type: %\n", debugCamera.type);
    print("followCamera2.type: %\n", followCamera2.type);
    print("followCamera.type: %\n", followCamera.type);
    print("type_of(followCamera): %\n", type_of(followCamera));
    print("type_of(refdef.camera): %\n", type_of(refdef.camera));
    print("type_of(cast(*FollowCamera)refdef.camera): %\n", type_of(cast(*FollowCamera)refdef.camera));
    thingy := cast(*FollowCamera)refdef.camera;
    print("thingy.target: %\n", type_of(thingy.target));
    print("refdef.camera.type: %\n", refdef.camera.type);

    // Safe mouse state, so we can get a delta
    mouseState : MouseState;

    running := true;
    while running {

        // Maybe even use SDL_GetKeyboardState() here and don't rely on SDL events at all?
        mouseX, mouseY : s32;
        buttonMask := SDL_GetMouseState(*mouseX, *mouseY);
        mouseState.oldX = mouseX;
        mouseState.oldY = mouseY;
        mouseState.rightButtonDown = false;        
        mouseState.rightButtonWentUp = false;
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

                    if event.key.keysym.sym == SDLK_h   keyState[SDLK_h] = true;
                    if event.key.keysym.sym == SDLK_f   keyState[SDLK_f] = true;
                    if event.key.keysym.sym == SDLK_t   keyState[SDLK_t] = true;
                    if event.key.keysym.sym == SDLK_g   keyState[SDLK_g] = true;
                    if event.key.keysym.sym == SDLK_i   keyState[SDLK_i] = true;
                    if event.key.keysym.sym == SDLK_k   keyState[SDLK_k] = true;

                    if event.key.keysym.sym == SDLK_1   keyState[SDLK_1] = true;
                    if event.key.keysym.sym == SDLK_2   keyState[SDLK_2] = true;


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

                    if event.key.keysym.sym == SDLK_h   keyState[SDLK_h] = false;
                    if event.key.keysym.sym == SDLK_f   keyState[SDLK_f] = false;
                    if event.key.keysym.sym == SDLK_t   keyState[SDLK_t] = false;
                    if event.key.keysym.sym == SDLK_g   keyState[SDLK_g] = false;
                    if event.key.keysym.sym == SDLK_i   keyState[SDLK_i] = false;
                    if event.key.keysym.sym == SDLK_k   keyState[SDLK_k] = false;

                    if event.key.keysym.sym == SDLK_1   keyState[SDLK_1] = false;
                    if event.key.keysym.sym == SDLK_2   keyState[SDLK_2] = false;

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
                        mouseState.dX = mouseX - mouseState.oldX;
                        mouseState.dY = mouseY - mouseState.oldY;                        
                        mouseState.rightButtonDown = true;
                        // UpdateCameraOnMouse(*refdef.camera, dX, dY); // TODO: Move this down, out of the event loop
                        //print("Mouse delta %, %\n", dX, dY);
                        mouseState.oldX = mouseX;
                        mouseState.oldY = mouseY;
                    }
                
                case SDL_MOUSEBUTTONUP;
                    mouseState.oldX = 0;
                    mouseState.oldY = 0;
                    mouseState.rightButtonDown = false;
                    if event.button.button & SDL_BUTTON_RIGHT == SDL_BUTTON_RIGHT {
                        mouseState.rightButtonWentUp = true;
                    }

                case SDL_WINDOWEVENT;
                    if event.window.event == SDL_WINDOWEVENT_RESIZED {
                        refdef.clientWidth = xx event.window.data1;
                        refdef.clientHeight = xx event.window.data2;
                        print("Window client dimensions have changed: ( %, % )\n", refdef.clientWidth, refdef.clientHeight);
                    }                    

            }
        }

        // Update stuff
        if keyState[SDLK_1] refdef.camera = *debugCamera;
        if keyState[SDLK_2] refdef.camera = *followCamera;
        UpdateWorld(keyState, mouseState, *refdef, *world);

        // Test triangle picking
        hitRecord := PickTri(refdef.camera, .{cast(float)mouseX, cast(float)(cast(s32)refdef.clientHeight - mouseY)}, refdef.clientWidth, refdef.clientHeight, world.models);
        if hitRecord.success {
            // print("t: %\n", rayLength);
            tri := hitRecord.tri;

            tri.a.color = .{1.0, 0.95, 0.0};
            tri.b.color = .{1.0, 0.95, 0.0};
            tri.c.color = .{1.0, 0.95, 0.0};
            // Pull the tris 'out' just a little bit so that they won't rejected during
            // rasterization because of failing the depth test.
            tri.a.pos += 0.0001*tri.a.normal;
            tri.b.pos += 0.0001*tri.b.normal;
            tri.c.pos += 0.0001*tri.c.normal;
            tris : [1]Tri;
            tris[0] = tri;
            Draw3DImmediateTris(tris, depthTest = true);
            hudScaleFactor := clamp(3.0 - hitRecord.distance, 1.0, 3.0);
            hudScale := 10*hudScaleFactor;
            DrawHUD(*refdef, crosshairHUD, 
                xPos = cast(float)refdef.clientWidth/2.0 - hudScale/2.0, 
                yPos = cast(float)refdef.clientHeight/2.0 - hudScale/2.0, 
                scaleX = hudScale, scaleY = hudScale);
        } else {
            DrawHUD(*refdef, crosshairHUD, 
                xPos = cast(float)refdef.clientWidth/2.0 - 5.0, 
                yPos = cast(float)refdef.clientHeight/2.0 - 5.0, 
                scaleX = 10.0, scaleY = 10.0);
        }

        // TODO: Right now, depth testing is disabled for Immediate 3D drawing. Fix it without breaking Triangle Picking.
        someTris := Tri.[
            .{
                .{pos = .{ 0.0, 0.0, -1.0}, color = .{0.8, 0.1, 0.9}},
                .{pos = .{ 1.0, 0.0, -1.0}, color = .{0.8, 0.1, 0.9}},
                .{pos = .{ 1.0, 1.0, -1.0}, color = .{0.8, 0.1, 0.9}}
            },   
            .{
                .{pos = .{ 1.0, 1.0, -1.0}, color = .{0.8, 0.1, 0.9}},
                .{pos = .{ 0.0, 1.0, -1.0}, color = .{0.8, 0.1, 0.9}},
                .{pos = .{ 0.0, 0.0, -1.0}, color = .{0.8, 0.1, 0.9}}
            }
        ];
        Draw3DImmediateTris(someTris);

        Draw3DImmediateLines(.[
            .{
             a = .{pos = .{ -1.0, -1.0, -1.0}, color = .{1.0, 0.0, 1.0}},
             b = .{pos = .{ 10.0, 10.0, 10.0}, color = .{1.0, 0.0, 1.0}}
            }
        ]);

        // Render settings
        refdef.wireframe = keyState[SDLK_TAB];        

        // Rendition
        DrawFrame(refdef);
    }

    SDL_DestroyWindow(refdef.window);
    SDL_Quit();

}
