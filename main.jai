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
#load "iqmloader.jai";

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

    RenderInit();

    InputInit();

    crosshairHUD := CreateHUD("crosshair_point.png");

    brushes, entities := LoadMapFile("assets/maps/simpleroom.map");
    // Init world and upload the world geometry to GPU
    world : World;
    //world := Model.{ position = .{0.0, 0.0, 0.0}};
    for brush : brushes {        
        height := brush.height;
        model : Model;
        model.textureID = RegisterTexture(brush.texture);
        heightScale := transpose(scale(Matrix3_Identity, Vector3.{1.0, height, 1.0}));
        for tri : GEOM_UNIT_CUBE {
            t := tri;
            brushOffset := Vector3.{brush.xPos, brush.yPos, brush.zPos};
            t.a.pos = heightScale*t.a.pos;
            t.b.pos = heightScale*t.b.pos;
            t.c.pos = heightScale*t.c.pos;
            t.a.pos += brushOffset;
            t.b.pos += brushOffset; 
            t.c.pos += brushOffset;
            array_add(*model.tris, t);
        }
        model.aabb = ComputeAABB(model.tris);
        model.position = Vector3.{brush.xPos, brush.yPos, brush.zPos};
        array_add(*world.models, model);
        RegisterModel(*model); // Upload to GPU
    }
    // Initialize Entities
    SpawnEntities(entities, *refdef, *world);

    // Add a nice texture to the model
    // world.textureID = RegisterTexture("wood_planks_01.tga");
    // modelID := RegisterModel(*world);

    debugCamera := CreateCamera(.{ pos = .{0.0, -10.0, 20.0}, fov = 50.0 }); // Move cam 'back' a little bit (+z comes out of the monit... OUCH!)
    refdef.camera = *debugCamera;
    followCamera := CreateFollowCamera(.{ pos = .{world.player.pos.x, world.player.pos.y + 1, world.player.pos.z - 1}, fov = 50.0 }, *world.player, 10.0);
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

        // memset(keyStatePrevFrame.data, cast(u8)(false), keyStatePrevFrame.count*size_of(bool));
        memcpy(keyStatePrevFrame.data, keyState.data, keyState.count*size_of(bool));

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
                    if event.key.keysym.sym == {
                        case .SDLK_a; keyState[KeyboardButton.A] = true;
                        case .SDLK_b; keyState[KeyboardButton.B] = true;
                        case .SDLK_c; keyState[KeyboardButton.C] = true;
                        case .SDLK_d; keyState[KeyboardButton.D] = true;
                        case .SDLK_e; keyState[KeyboardButton.E] = true;
                        case .SDLK_f; keyState[KeyboardButton.F] = true;
                        case .SDLK_g; keyState[KeyboardButton.G] = true;
                        case .SDLK_h; keyState[KeyboardButton.H] = true;
                        case .SDLK_i; keyState[KeyboardButton.I] = true;
                        case .SDLK_j; keyState[KeyboardButton.J] = true;
                        case .SDLK_k; keyState[KeyboardButton.K] = true;
                        case .SDLK_l; keyState[KeyboardButton.L] = true;
                        case .SDLK_m; keyState[KeyboardButton.M] = true;
                        case .SDLK_n; keyState[KeyboardButton.N] = true;
                        case .SDLK_o; keyState[KeyboardButton.O] = true;
                        case .SDLK_p; keyState[KeyboardButton.P] = true;
                        case .SDLK_q; keyState[KeyboardButton.Q] = true;
                        case .SDLK_r; keyState[KeyboardButton.R] = true;
                        case .SDLK_s; keyState[KeyboardButton.S] = true;
                        case .SDLK_t; keyState[KeyboardButton.T] = true;
                        case .SDLK_u; keyState[KeyboardButton.U] = true;
                        case .SDLK_v; keyState[KeyboardButton.V] = true;
                        case .SDLK_w; keyState[KeyboardButton.W] = true;
                        case .SDLK_x; keyState[KeyboardButton.X] = true;
                        case .SDLK_y; keyState[KeyboardButton.Y] = true;
                        case .SDLK_z; keyState[KeyboardButton.Z] = true;                        

                        case .SDLK_RIGHT; keyState[KeyboardButton.RIGHT] = true;    
                        case .SDLK_LEFT; keyState[KeyboardButton.LEFT] = true;    
                        case .SDLK_UP; keyState[KeyboardButton.UP] = true;    
                        case .SDLK_DOWN; keyState[KeyboardButton.DOWN] = true;                            

                        case .SDLK_1; keyState[KeyboardButton.NUM_1] = true;
                        case .SDLK_2; keyState[KeyboardButton.NUM_2] = true;

                        case .SDLK_ESCAPE; keyState[KeyboardButton.ESCAPE] = true;                            
                        case .SDLK_COMMA; keyState[KeyboardButton.COMMA] = true;
                        case .SDLK_PERIOD; keyState[KeyboardButton.PERIOD] = true;    
                        case .SDLK_TAB; keyState[KeyboardButton.TAB] = true;

                        case; print("Button not mapped\n");
                    }
            
                case SDL_KEYUP;
                    // memcpy(keyStatePrevFrame.data, keyState.data, keyState.count*size_of(bool));
                    if event.key.keysym.sym == {
                        case .SDLK_a; keyState[KeyboardButton.A] = false;
                        case .SDLK_b; keyState[KeyboardButton.B] = false;
                        case .SDLK_c; keyState[KeyboardButton.C] = false;
                        case .SDLK_d; keyState[KeyboardButton.D] = false;
                        case .SDLK_e; keyState[KeyboardButton.E] = false;
                        case .SDLK_f; keyState[KeyboardButton.F] = false;
                        case .SDLK_g; keyState[KeyboardButton.G] = false;
                        case .SDLK_h; keyState[KeyboardButton.H] = false;
                        case .SDLK_i; keyState[KeyboardButton.I] = false;
                        case .SDLK_j; keyState[KeyboardButton.J] = false;
                        case .SDLK_k; keyState[KeyboardButton.K] = false;
                        case .SDLK_l; keyState[KeyboardButton.L] = false;
                        case .SDLK_m; keyState[KeyboardButton.M] = false;
                        case .SDLK_n; keyState[KeyboardButton.N] = false;
                        case .SDLK_o; keyState[KeyboardButton.O] = false;
                        case .SDLK_p; keyState[KeyboardButton.P] = false;
                        case .SDLK_q; keyState[KeyboardButton.Q] = false;
                        case .SDLK_r; keyState[KeyboardButton.R] = false;
                        case .SDLK_s; keyState[KeyboardButton.S] = false;
                        case .SDLK_t; keyState[KeyboardButton.T] = false;
                        case .SDLK_u; keyState[KeyboardButton.U] = false;
                        case .SDLK_v; keyState[KeyboardButton.V] = false;
                        case .SDLK_w; keyState[KeyboardButton.W] = false;
                        case .SDLK_x; keyState[KeyboardButton.X] = false;
                        case .SDLK_y; keyState[KeyboardButton.Y] = false;
                        case .SDLK_z; keyState[KeyboardButton.Z] = false;                        

                        case .SDLK_RIGHT; keyState[KeyboardButton.RIGHT] = false;    
                        case .SDLK_LEFT; keyState[KeyboardButton.LEFT] = false;    
                        case .SDLK_UP; keyState[KeyboardButton.UP] = false;    
                        case .SDLK_DOWN; keyState[KeyboardButton.DOWN] = false;                            

                        case .SDLK_1; keyState[KeyboardButton.NUM_1] = false;
                        case .SDLK_2; keyState[KeyboardButton.NUM_2] = false;

                        case .SDLK_ESCAPE; keyState[KeyboardButton.ESCAPE] = false;                            
                        case .SDLK_COMMA;  keyState[KeyboardButton.COMMA] = false;                                                    
                        case .SDLK_PERIOD; keyState[KeyboardButton.PERIOD] = false;                        
                        case .SDLK_TAB; keyState[KeyboardButton.TAB] = false;                            
                        
                        case; print("Button not mapped\n");
                    }
                    
                    // if event.key.keysym.sym == SDLK_COMMA {
                    //     keyStatePrevFrame[SDLK_COMMA] = keyState[SDLK_COMMA];
                    //     keyState[SDLK_COMMA] = false;
                    // }
                    // if event.key.keysym.sym == SDLK_PERIOD {
                    //     keyStatePrevFrame[SDLK_PERIOD] = keyState[SDLK_PERIOD];
                    //     keyState[SDLK_PERIOD] = false;
                    // }

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

        if KeyPressed(KeyboardButton.ESCAPE) running = false;    

        // Update stuff
        if KeyPressed(KeyboardButton.NUM_1) refdef.camera = *debugCamera;
        if KeyPressed(KeyboardButton.NUM_2) refdef.camera = *followCamera;
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
        if KeyDown(KeyboardButton.TAB) {
            print("tab down once\n");
            refdef.wireframe = !refdef.wireframe;
        }
    
        // Rendition
        DrawFrame(refdef);

        // Clear per-frame allocations
        reset_temporary_storage();
    }

    SDL_DestroyWindow(refdef.window);
    SDL_Quit();

}
