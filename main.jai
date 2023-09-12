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
#load "quakemap_parser.jai";

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

    perfFrequency : u64 = SDL_GetPerformanceFrequency(); // in Hz -> Says how often the performance counter is incremented.

    RenderInit();

    InputInit();

    crosshairHUD := CreateHUD("crosshair_point.png");

    map : QuakeMap = ParseQuakeMap("assets/maps/first_quake.map");
    qworld := InitWorldFromQuakeMap(map);
    exit(-1);

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



    frameTime : float;
    running := true;
    while running {

        perfCounterBeginFrame := SDL_GetPerformanceCounter();

        HandleSystemEvents(*running, *refdef);

        if KeyPressed(KeyboardButton.ESCAPE) running = false;    

        // Update stuff
        if KeyPressed(KeyboardButton.NUM_1) refdef.camera = *debugCamera;
        if KeyPressed(KeyboardButton.NUM_2) refdef.camera = *followCamera;
                
        UpdateWorld(*refdef, *world, frameTime);

        // Test triangle picking
        hitRecord := PickTri(refdef.camera, .{cast(float)GetMouseX(), cast(float)(cast(s32)refdef.clientHeight - GetMouseY())}, refdef.clientWidth, refdef.clientHeight, world.models);
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

        // Draw coordinate axis
        Draw3DImmediateLines(.[
            .{
             a = .{pos = .{ 0.0, 0.0, 0.0}, color = .{1.0, 0.0, 0.0}},
             b = .{pos = .{ 10.0, 0.0, 0.0}, color = .{1.0, 0.0, 0.0}}
            },
            .{
             a = .{pos = .{ 0.0, 0.0, 0.0}, color = .{0.0, 1.0, 0.0}},
             b = .{pos = .{ 0.0, 10.0, 0.0}, color = .{0.0, 1.0, 0.0}}
            },
            .{
             a = .{pos = .{ 0.0, 0.0, 0.0}, color = .{0.0, 0.0, 1.0}},
             b = .{pos = .{ 0.0, 0.0, 10.0}, color = .{0.0, 0.0, 1.0}}
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

        perfCounterEndFrame := SDL_GetPerformanceCounter();

        perfDelta := perfCounterEndFrame - perfCounterBeginFrame;
        frameTime = cast(float)perfDelta / cast(float)perfFrequency;
        print("frameTime: % seconds\n", frameTime);
    }

    SDL_DestroyWindow(refdef.window);
    SDL_Quit();

}
