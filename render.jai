#import "Basic";
#import "GL";
#import "SDL";
#import "Math";
#import "File";

// TODOS:
// We probably do not need to store the vertices on CPU side inside this module.


// Shaders
gStaticWorldProgram : GLuint;
wireframeShaderProgram : GLuint; // TODO: Not used
HUDShaderProgram : GLuint;
gImmediate3DProgram : GLuint;
gEntityShaderProgram : GLuint;

// Uniform Buffers for world geometry
viewProjectionUBO : GLuint;
perFrameSettingsUBO : GLuint;
// VBOs, VAOs per batch for world geometry
batches : [..] Batch;

// VBOs, VAOs for entities
entityModels : [..] EntityModel;

// UBO for animation matrices and some hard constraints
MAX_SKELETON_JOINTS :: 128;
poseMatrixUBO : GLuint;

// Immediate 3D
gImmediateVBO               : GLuint;
gImmediateVAO               : GLuint;
MAX_IMMEDIATE3D_DRAW_CMDS   :: 256;
gImmediate3DDrawCmds        : [MAX_IMMEDIATE3D_DRAW_CMDS] Immediate3DDrawCmd;
gImmediate3DDrawCmdCount    : s32;
IMMEDIATE3D_BUFFER_SIZE     :: (1024*3*size_of(Vertex));

// TODO: God, this is so ugly. Can we do better with dynamic array?
MAX_HUD_DRAW_CMDS : u32 : 128;
HUDDrawCount      : s32;

MAX_ENTITIES      : s32 : 1024;
entityCount       : s32;

// Draw Settings for one frame
RefDef :: struct {
    clientWidth         : u32 = 1024;
    clientHeight        : u32 = 768;
    window              : *SDL_Window;
    camera              : *Camera;
    wireframe           := false;

    HUDDrawList         : [MAX_HUD_DRAW_CMDS] HUDDrawCmd;
    entities            : [MAX_ENTITIES] Entity;
};

// Models for entities (Players, Monsters, Pickup Items...)
EntityModel :: struct {
    VAO, VBO    : GLuint;
    vertices    : [..] Vertex;
    textureID   : u32;
}

EntityTransform :: struct {
    transform := Matrix4_Identity;
}
entityTransformUBO : GLuint;

// HUD
HUDElement :: struct {
    VAO, VBO    : GLuint;
    textureID   : u32;
    vertices    : [..] Vertex;
}

HUDDrawCmd :: struct {
    hudID       : u32;
    transform   : HUDTransform;
}

HUDTransform :: struct {
    pos     : Vector2;
    scaleXY : Vector2;
}

HUDWindowData :: struct {
    clientDimensions : Vector2;
}
// Stores VAO, VBO for each HUD element (wasteful!). TODO: Batch HUD elements.
hudElements : [..] HUDElement;
// Uniform for HUD
hudTransformUBO     : GLuint;
hudWindowDataUBO    : GLuint;

DrawHUD :: (refdef : *RefDef, hudElem : CHUDElement, xPos : float = 0.0, yPos : float = 0.0, scaleX : float = 1.0, scaleY : float = 1.0) {
    drawCmd := HUDDrawCmd.{
        hudID = hudElem.id, 
        transform = HUDTransform.{ 
            pos     = .{x=xPos, y=yPos}, 
            scaleXY = .{x = scaleX, y = scaleY}
        }
    };

    refdef.HUDDrawList[HUDDrawCount] = drawCmd;
    HUDDrawCount += 1;
}

Immediate3DDrawCmd :: struct {
    primitiveType   : GLenum = GL_TRIANGLES;
    depthTest       := true;
    offset          : u32; // Byte offset into Vertex buffer    
    firstVertex     : u32;
    vertexCount     : u32;
};

Batch :: struct {
    VAO, VBO         : GLuint;
    textureID        : u32;
    totalVertexCount : u32; // TODO: Why is this here again? vertices.count gives us that!
    vertices         : [..] Vertex;
}

ViewProjMatrices :: struct {
    view := Matrix4_Identity;
    proj := Matrix4_Identity;
}

PerFrameSettings :: struct {
    drawWireframe : u32 = 0;
}

CreateBatch :: () -> *Batch {
    result : Batch;
    glGenVertexArrays(1, *result.VAO);
    glBindVertexArray(result.VAO);

    glGenBuffers(1, *result.VBO);
    glBindBuffer(GL_ARRAY_BUFFER, result.VBO);

    // Input assembly for vertex shader
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), null);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)size_of(Vector3));
    glEnableVertexAttribArray(1);

    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2)));
    glEnableVertexAttribArray(2);

    glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2) + size_of(Vector3)));
    glEnableVertexAttribArray(3);

    glVertexAttribPointer(4, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2) + size_of(Vector3) + size_of(Vector3)));
    glEnableVertexAttribArray(4);

    // Allocate enough space for 1024 quads
    glBufferData(GL_ARRAY_BUFFER, 1024 * 6 * size_of(Vertex), null, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    array_add(*batches, result);

    return *batches[batches.count - 1];
}

InitImmediateBuffers :: () {
    glGenVertexArrays(1, *gImmediateVAO);
    glBindVertexArray(gImmediateVAO);

    glGenBuffers(1, *gImmediateVBO);
    glBindBuffer(GL_ARRAY_BUFFER, gImmediateVBO);

    // Input assembly for vertex shader
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), null);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)size_of(Vector3));
    glEnableVertexAttribArray(1);

    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2)));
    glEnableVertexAttribArray(2);

    glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2) + size_of(Vector3)));
    glEnableVertexAttribArray(3);

    glVertexAttribPointer(4, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2) + size_of(Vector3) + size_of(Vector3)));
    glEnableVertexAttribArray(4);

    // Allocate enough space for 1024 tris
    glBufferData(GL_ARRAY_BUFFER, IMMEDIATE3D_BUFFER_SIZE, null, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

RenderAddEntity :: (refdef : *RefDef, entity : Entity) {
    if entityCount >= MAX_ENTITIES {
        print("RenderAddEntity: No more space left for more entities!\n");
        return;
    }

    refdef.entities[entityCount] = entity;
    entityCount += 1;
}

CreateEntityModel :: (tris : [] Tri, textureID : u32) -> u32 {
    result : EntityModel; 
    result.textureID = textureID;
    
    for tris {
        array_add(*result.vertices, it.a);
        array_add(*result.vertices, it.b);
        array_add(*result.vertices, it.c);
    }

    glGenVertexArrays(1, *result.VAO);
    glBindVertexArray(result.VAO);

    glGenBuffers(1, *result.VBO);
    glBindBuffer(GL_ARRAY_BUFFER, result.VBO);

    // Input assembly for vertex shader
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), null);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)size_of(Vector3));
    glEnableVertexAttribArray(1);

    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2)));
    glEnableVertexAttribArray(2);

    glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2) + size_of(Vector3)));
    glEnableVertexAttribArray(3);

    glVertexAttribPointer(4, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2) + size_of(Vector3) + size_of(Vector3)));
    glEnableVertexAttribArray(4);

    glVertexAttribIPointer(5, 4, GL_UNSIGNED_INT, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2) + size_of(Vector3) + size_of(Vector3)) + size_of(Vector3));
    glEnableVertexAttribArray(5);

    glVertexAttribPointer(6, 4, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2) + size_of(Vector3) + size_of(Vector3)) + size_of(Vector3) + 4*size_of(u32));
    glEnableVertexAttribArray(6);    

    glBufferData(GL_ARRAY_BUFFER, tris.count * 3 * size_of(Vertex), tris.data, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    array_add(*entityModels, result);

    return cast(u32)(entityModels.count - 1);
}

// TODO: ImmediateTris and ImmediateLines are fairly similar. I am sure Jai offers some way to
//       compress this in a neat way.
Draw3DImmediateTris :: (tris : [] Tri, depthTest := true) {
    size := tris.count * size_of(Tri);

    offset := 0;
    firstVertex := 0;
    if gImmediate3DDrawCmdCount > 0 {
        lastDrawCmd := gImmediate3DDrawCmds[gImmediate3DDrawCmdCount-1];
        firstVertex = lastDrawCmd.firstVertex + lastDrawCmd.vertexCount;
        offset = lastDrawCmd.offset + lastDrawCmd.vertexCount * size_of(Vertex);
        if (offset + size) >= IMMEDIATE3D_BUFFER_SIZE {
            // print("Draw3DImmediateTris: Immmediate 3D GL buffer full! Discarding draw command!\n");
            return;
        }
    }

    glBindVertexArray(gImmediateVAO);
    glBindBuffer(GL_ARRAY_BUFFER, gImmediateVBO);    
    glBufferSubData(GL_ARRAY_BUFFER, offset, size, tris.data);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    drawCmd := Immediate3DDrawCmd.{
        offset = xx offset,
        firstVertex = xx firstVertex,
        vertexCount = xx (tris.count * 3),
        depthTest = depthTest
    };

    gImmediate3DDrawCmds[gImmediate3DDrawCmdCount] = drawCmd;
    gImmediate3DDrawCmdCount += 1;

    // gImmediateOffset += xx size;
    // gImmediateVertexCount += xx (tris.count * 3);
}

// Put two Vertex into the immediate buffer and draw in the order
// they were put in. If the VBO is full, discard this command.
Draw3DImmediateLines :: (lines : [] Line, depthTest := true) {
    size := lines.count * size_of(Line);

    offset := 0;
    firstVertex := 0;
    if gImmediate3DDrawCmdCount > 0 {
        lastDrawCmd := gImmediate3DDrawCmds[gImmediate3DDrawCmdCount-1];
        firstVertex = lastDrawCmd.firstVertex + lastDrawCmd.vertexCount;
        offset = lastDrawCmd.offset + lastDrawCmd.vertexCount * size_of(Vertex);
        if (size + offset) >= IMMEDIATE3D_BUFFER_SIZE {
            return;
        }
    }

    glBindVertexArray(gImmediateVAO);
    glBindBuffer(GL_ARRAY_BUFFER, gImmediateVBO);    
    glBufferSubData(GL_ARRAY_BUFFER, offset, size, lines.data);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    drawCmd := Immediate3DDrawCmd.{
        primitiveType = GL_LINES,
        offset = xx offset,
        firstVertex = xx firstVertex,
        vertexCount = xx (lines.count * 2),
        depthTest = depthTest
    };

    gImmediate3DDrawCmds[gImmediate3DDrawCmdCount] = drawCmd;
    gImmediate3DDrawCmdCount += 1;
}

Draw3DImmediateLinesPtr :: (lines : *Line, count : u32, depthTest := true) {
    size := count * size_of(Line);

    offset := 0;
    firstVertex := 0;
    if gImmediate3DDrawCmdCount > 0 {
        lastDrawCmd := gImmediate3DDrawCmds[gImmediate3DDrawCmdCount-1];
        firstVertex = lastDrawCmd.firstVertex + lastDrawCmd.vertexCount;
        offset = lastDrawCmd.offset + lastDrawCmd.vertexCount * size_of(Vertex);
    }

    glBindVertexArray(gImmediateVAO);
    glBindBuffer(GL_ARRAY_BUFFER, gImmediateVBO);    
    glBufferSubData(GL_ARRAY_BUFFER, offset, size, lines);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    drawCmd := Immediate3DDrawCmd.{
        primitiveType = GL_LINES,
        offset = xx offset,
        firstVertex = xx firstVertex,
        vertexCount = xx (count * 2),
        depthTest = depthTest
    };

    gImmediate3DDrawCmds[gImmediate3DDrawCmdCount] = drawCmd;
    gImmediate3DDrawCmdCount += 1;
}

// Directly draw an AABB. It is not the nicest code! Should be replaced at some point.
Draw3DAABB :: (aabb : AABB, color := Vector3.{1.0, 0.0, 0.0}) {
    boxTris : [12] Tri;
    
    scaleExtents := aabb.maxXYZ - aabb.minXYZ;
    centerPos := aabb.minXYZ + scaleExtents/2.0;

    transform := translate(Matrix4_Identity, centerPos);
    transform = transpose(scale(transform, abs(scaleExtents)));
    for GEOM_UNIT_CUBE_CENTER {    
        // TODO: All of those vector conversions between v3 and v4 is kinda annoying!
        //       Is there a good way in jai to do this? like in glm: glm::vec4(myVec3, 1.0); ?
        a := Mat4XVec4(transform, vec3toVec4(it.a.pos));
        b := Mat4XVec4(transform, vec3toVec4(it.b.pos));
        c := Mat4XVec4(transform, vec3toVec4(it.c.pos));
        a3 := Vector3.{a.x, a.y, a.z};
        b3 := Vector3.{b.x, b.y, b.z};
        c3 := Vector3.{c.x, c.y, c.z};
        boxTris[it_index].a.pos = a3 + 0.0001*it.a.normal;
        boxTris[it_index].b.pos = b3 + 0.0001*it.b.normal;
        boxTris[it_index].c.pos = c3 + 0.0001*it.c.normal;
        boxTris[it_index].a.color = color;
        boxTris[it_index].b.color = color;
        boxTris[it_index].c.color = color;
    }
    Draw3DImmediateTris(boxTris);
}

RenderPrepare :: () {
    // Some general GL settings. Must be set BEFORE SDL creates the OpenGL context!
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, xx SDL_GL_CONTEXT_DEBUG_FLAG);
}

MessageCallback :: (source : GLenum,
                 type : GLenum,
                 id : GLuint,
                 severity : GLenum,
                 length : GLsizei,
                 message : *u8,
                 userParam : *void) -> void #c_call
{
    new_context : Context;
    push_context new_context {
        severityString := "";
        if severity == GL_DEBUG_SEVERITY_HIGH severityString = "HIGH";
        if severity == GL_DEBUG_SEVERITY_MEDIUM severityString = "MEDIUM";
        if severity == GL_DEBUG_SEVERITY_LOW severityString = "LOW";
        if severity == GL_DEBUG_SEVERITY_NOTIFICATION severityString = "NOTIFICATION";
        if severity != GL_DEBUG_SEVERITY_NOTIFICATION {
            print("GL CALLBACK: % type = %, severity = %, message = %\n", "foo", type, severityString, to_string(message) );
        }
    }
}

// TODO: Are there namespaces? Or do we have to prefix stuff? Because we could have just Render::Init(), maybe?
RenderInit :: () {

    // Load GL function pointers
    gl_load(*gl, SDL_GL_GetProcAddress);
    using gl; // TODO: Why? This is not really needed?

    print("GL Vendor = %\n", to_string(glGetString(GL_VENDOR)));
    print("GL Version = %\n", to_string(glGetString(GL_VERSION)));

    // Set GL states
    glEnable(GL_DEBUG_OUTPUT);
    glDebugMessageCallback(MessageCallback, null);

    glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glCullFace(GL_BACK);
    glFrontFace(GL_CCW);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Shaders
    gStaticWorldProgram = CreateShaderProgram("shaders/basic_world.vert", "shaders/basic_world.frag");
    // wireframeShaderProgram = CreateShaderProgram("shaders/basic_world.vert", "shaders/wireframe.frag");
    HUDShaderProgram = CreateShaderProgram("shaders/hud.vert", "shaders/hud.frag");
    gImmediate3DProgram = CreateShaderProgram("shaders/immediate3D.vert", "shaders/immediate3D.frag");
    gEntityShaderProgram = CreateShaderProgram("shaders/entities.vert", "shaders/entities.frag");

    // VAO/VBO for immediat 3D
    InitImmediateBuffers();

    // Per Frame Data (as of now: view proj matrices)
    // The following way of initializing the buffers causes the shader programs, for whatever reason,
    // to get other values...

    // uniformBuffers : [4] *GLuint;
    // uniformBuffers[0] = *viewProjectionUBO;
    // uniformBuffers[1] = *perFrameSettingsUBO;
    // uniformBuffers[2] = *hudTransformUBO;
    // uniformBuffers[3] = *hudWindowDataUBO;
    // glGenBuffers(xx uniformBuffers.count, uniformBuffers[0]);

    // This, however, seems to work.
    glGenBuffers(1, *viewProjectionUBO);
    glGenBuffers(1, *perFrameSettingsUBO);
    glGenBuffers(1, *hudTransformUBO);
    glGenBuffers(1, *hudWindowDataUBO);
    glGenBuffers(1, *entityTransformUBO);
    glGenBuffers(1, *poseMatrixUBO);

    // glBindBuffer(GL_UNIFORM_BUFFER, UBO);
    // glBufferData(GL_UNIFORM_BUFFER, size_of(ViewProjMatrices), *viewProjMatrices, GL_STATIC_DRAW);
    // glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, viewProjectionUBO); // index (0) matches UBO binding ID in shader.
    glBindBufferBase(GL_UNIFORM_BUFFER, 1, perFrameSettingsUBO);
    
    glBindBufferBase(GL_UNIFORM_BUFFER, 2, hudTransformUBO);
    glBindBufferBase(GL_UNIFORM_BUFFER, 3, hudWindowDataUBO);    

    glBindBufferBase(GL_UNIFORM_BUFFER, 4, entityTransformUBO);

    glBindBufferBase(GL_UNIFORM_BUFFER, 5, poseMatrixUBO);

    glBindBuffer(GL_UNIFORM_BUFFER, viewProjectionUBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(ViewProjMatrices), null, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, perFrameSettingsUBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(PerFrameSettings), null, GL_DYNAMIC_DRAW);

    glBindBuffer(GL_UNIFORM_BUFFER, hudTransformUBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(HUDTransform), null, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, hudWindowDataUBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(HUDWindowData), null, GL_DYNAMIC_DRAW);

    glBindBuffer(GL_UNIFORM_BUFFER, entityTransformUBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(EntityTransform), null, GL_DYNAMIC_DRAW);

    glBindBuffer(GL_UNIFORM_BUFFER, poseMatrixUBO);
    glBufferData(GL_UNIFORM_BUFFER, MAX_SKELETON_JOINTS*size_of(Matrix4), null, GL_DYNAMIC_DRAW);

    SDL_GL_SetSwapInterval(1); // VSYNC on, please.
}

CreateShader :: (shaderFile : string, shaderType : GLenum) -> GLuint {
    shaderCode := read_entire_file(shaderFile);    
    shader := glCreateShader(shaderType);
    
    code : [1] *u8 ;
    code[0] = shaderCode.data;
    length : [1] s32;
    length[0] = xx shaderCode.count;
    glShaderSource(shader, 1, code.data, length.data);
    
    glCompileShader(shader);
    
    glsuccess : GLint;
    glGetShaderiv(shader, GL_COMPILE_STATUS, *glsuccess);

    if !glsuccess then {
        logData: [1024] u8;
        glGetShaderInfoLog(shader, logData.count, null, logData.data);
        log("Failed to compile shader %:\n%", shaderFile, to_string(logData.data), flags=.ERROR);
        exit(-1);
    }

    return shader;
}

CreateShaderProgram :: (vertShaderFile : string, fragShaderFile : string) -> GLuint {
    vertShader := CreateShader(vertShaderFile, GL_VERTEX_SHADER);
    fragShader := CreateShader(fragShaderFile, GL_FRAGMENT_SHADER);

    shaderProgram := glCreateProgram();
    print("type_of(shaderProgram): %, value: %\n", type_of(shaderProgram), shaderProgram);
    glAttachShader(shaderProgram, vertShader);
    glAttachShader(shaderProgram, fragShader);
    glLinkProgram(shaderProgram);
    linkStatus : GLint;
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, *linkStatus);
    if !linkStatus {
        info_len : s32;
        glGetProgramiv (shaderProgram, GL_INFO_LOG_LENGTH, *info_len);
        info_data := cast (*u8) alloc (info_len, temp);
        glGetProgramInfoLog (shaderProgram, xx info_len, xx *info_len, info_data);
        result : string;
        result.data = info_data;
        result.count = info_len;
        log("Failed to link shader program:\n%\n", result, flags=.ERROR);
        exit(-1);
    }
    glDeleteShader(vertShader);
    glDeleteShader(fragShader);

    return shaderProgram;
}

// NOTE: This is almost the same as RegisterModel below.
// RegisterModel is kinda obsolete now that we create
// a triangle soup from a Quake map. If we decide that
// we still want to keep the old way of loading maps using
// the old map format we should unify the function, because
// there is so much duplicate code around here.
// We will see.
WorldTrisToGPU :: (tris : [] WorldTri) {
    findBatchByTexID :: (textureID : u32) -> *Batch {
        if batches.count <= textureID {
            return null;
        }
        else {
            return *batches[textureID];
        }
    }

    for tris {
        batch := findBatchByTexID(it.textureID);
        if !batch {
            batch = CreateBatch();
            batch.textureID = it.textureID;
        }

        array_add(*batch.vertices, it.vertices[0]);
        array_add(*batch.vertices, it.vertices[1]);
        array_add(*batch.vertices, it.vertices[2]);

        lastVertexOffset := batch.totalVertexCount * size_of(Vertex);
        dataSize := 3 * size_of(Vertex);

        glBindVertexArray(batch.VAO);
        glBindBuffer(GL_ARRAY_BUFFER, batch.VBO);    
        glBufferSubData(GL_ARRAY_BUFFER, lastVertexOffset, dataSize, batch.vertices.data + batch.totalVertexCount);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);

        batch.totalVertexCount += 3;    
    }
}

// This is obsolete and should not be used for now
RegisterModel :: (model : *Model) {
    findBatchByTexID :: (textureID : u32) -> *Batch {
        if batches.count <= textureID {
            return null;
        }
        else {
            return *batches[textureID];
        }
    }
    batch := findBatchByTexID(model.textureID);
    if !batch {
        batch = CreateBatch();
        batch.textureID = model.textureID;
    }

    for model.tris {
        v0 := it.a;
        v1 := it.b;
        v2 := it.c;
        array_add(*batch.vertices, v0);
        array_add(*batch.vertices, v1);
        array_add(*batch.vertices, v2);
    }
    lastVertexOffset := batch.totalVertexCount * size_of(Vertex);
    dataSize := model.tris.count * 3 * size_of(Vertex);

    glBindVertexArray(batch.VAO);
    glBindBuffer(GL_ARRAY_BUFFER, batch.VBO);    
    glBufferSubData(GL_ARRAY_BUFFER, lastVertexOffset, dataSize, batch.vertices.data + batch.totalVertexCount);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    
    batch.totalVertexCount += xx (model.tris.count * 3);    
}

RegisterHUD :: (model : *Model) {
    hudElem : HUDElement;
    for model.tris {
        v0 := it.a;
        v1 := it.b;
        v2 := it.c;
        array_add(*hudElem.vertices, v0);
        array_add(*hudElem.vertices, v1);
        array_add(*hudElem.vertices, v2);
    }
    

    glGenVertexArrays(1, *hudElem.VAO);
    glBindVertexArray(hudElem.VAO);

    glGenBuffers(1, *hudElem.VBO);
    glBindBuffer(GL_ARRAY_BUFFER, hudElem.VBO);

    // Input assembly for vertex shader
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), null);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)size_of(Vector3));
    glEnableVertexAttribArray(1);

    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2)));
    glEnableVertexAttribArray(2);

    glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2) + size_of(Vector3)));
    glEnableVertexAttribArray(3);
    
    glVertexAttribPointer(4, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2) + size_of(Vector3) + size_of(Vector3)));
    glEnableVertexAttribArray(4);

    dataSize := hudElem.vertices.count * size_of(Vertex);
    glBufferData(GL_ARRAY_BUFFER, dataSize, cast(*void)hudElem.vertices.data, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    array_add(*hudElements, hudElem);
    model.hudID = xx (hudElements.count - 1);
}

DrawFrame :: (refdef : RefDef) {
    glViewport(0, 0, refdef.clientWidth, refdef.clientHeight);    
    glClearColor(0.5, 0.5, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // World
    glUseProgram(gStaticWorldProgram);
    viewProjMatrices : ViewProjMatrices;
    viewProjMatrices.view = CreateView(refdef.camera);
    // viewProjMatrices.view = transpose(make_look_at_matrix(refdef.camera.pos, refdef.camera.center, refdef.camera.up, x_is_forward=false));

    viewProjMatrices.proj = Perspective(refdef.camera.fov * PI / 180.0, refdef.clientWidth / cast(float)refdef.clientHeight, 0.1, 1000.0);
    // viewProjMatrices.proj = transpose(make_projection_matrix(refdef.camera.fov * PI / 180.0, refdef.clientWidth / cast(float)refdef.clientHeight, 0.1, 1000.0));
    
    // TODO: Not sure if we should keep a buffer in mapped state...? Probably not worth it? Look this up in the gl-bible.
    glBindBuffer(GL_UNIFORM_BUFFER, viewProjectionUBO);
    // glBindBufferBase(GL_UNIFORM_BUFFER, 0, viewProjectionUBO);
    // ptr := glMapBuffer(GL_UNIFORM_BUFFER, GL_WRITE_ONLY);
    // memcpy(ptr, *viewProjMatrices, size_of(ViewProjMatrices));
    glBufferData(GL_UNIFORM_BUFFER, size_of(ViewProjMatrices), *viewProjMatrices, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    // glUnmapBuffer(GL_UNIFORM_BUFFER);

    // glBufferData(GL_UNIFORM_BUFFER, size_of(ViewProjMatrices), *viewProjMatrices, GL_STATIC_DRAW);
    // glBindBuffer(GL_UNIFORM_BUFFER, 0);

    // Can this check syntactically be more concise?
    perFrameSettings : PerFrameSettings;
    if refdef.wireframe {
        perFrameSettings.drawWireframe = 1;
    } else {
        perFrameSettings.drawWireframe = 0;
    }
    glBindBuffer(GL_UNIFORM_BUFFER, perFrameSettingsUBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(PerFrameSettings), *perFrameSettings, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    // ptr := glMapBuffer(GL_UNIFORM_BUFFER, GL_WRITE_ONLY);
    // memcpy(ptr, *perFrameSettings, size_of(PerFrameSettings));
    // glUnmapBuffer(GL_UNIFORM_BUFFER);

    // glBindBufferBase(GL_UNIFORM_BUFFER, 1, perFrameSettingsUBO);
    // glBufferData(GL_UNIFORM_BUFFER, size_of(PerFrameSettings), *perFrameSettings, GL_STATIC_DRAW);
    // glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glActiveTexture(GL_TEXTURE0);
    for batches {
        glBindVertexArray(it.VAO);            
        glBindTexture(GL_TEXTURE_2D, GetTextureHandleByID(it.textureID));
        glDrawArrays(GL_TRIANGLES, 0, xx it.vertices.count);
        
        // gl_Err := glGetError();
        // if gl_Err != GL_NO_ERROR {
        //     print("ERROR drawing world: GL Error: %\n", gl_Err);
        // }
    }
    glBindBuffer(GL_UNIFORM_BUFFER, 0);


    // Draw entities (for now just pretty much the same as world stuff)
    glUseProgram(gEntityShaderProgram);
    // glBindBuffer(GL_UNIFORM_BUFFER, viewProjectionUBO);
    // glBindBuffer(GL_UNIFORM_BUFFER, perFrameSettingsUBO);
    // ptr = glMapBuffer(GL_UNIFORM_BUFFER, GL_WRITE_ONLY);
    for i : 0..entityCount-1 {
        entity := refdef.entities[i];
        glBindBuffer(GL_UNIFORM_BUFFER, poseMatrixUBO);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, MAX_SKELETON_JOINTS*size_of(Matrix4), *entity.palette[0]);
        for entity.models {             
            entityModel := entityModels[it.gpuID];
            entityTransform := transpose(make_translation_matrix4(entity.pos));
            // memcpy(ptr, *entityTransform, size_of(EntityTransform));
            glBindBuffer(GL_UNIFORM_BUFFER, entityTransformUBO);
            glBufferData(GL_UNIFORM_BUFFER, size_of(EntityTransform), *entityTransform, GL_DYNAMIC_DRAW);
            glBindVertexArray(entityModel.VAO);
            glBindTexture(GL_TEXTURE_2D, GetTextureHandleByID(entityModel.textureID));
            glDrawArrays(GL_TRIANGLES, 0, xx entityModel.vertices.count);
        }
    }
    // glUnmapBuffer(GL_UNIFORM_BUFFER);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    

    // Immediate3D
    glUseProgram(gImmediate3DProgram);
    glDisable(GL_CULL_FACE);
    glBindBuffer(GL_UNIFORM_BUFFER, viewProjectionUBO);
    glBindVertexArray(gImmediateVAO);
    for i : 0..gImmediate3DDrawCmdCount-1 {
        drawCmd := gImmediate3DDrawCmds[i];
        if !drawCmd.depthTest glDisable(GL_DEPTH_TEST);
        glDrawArrays(drawCmd.primitiveType, xx drawCmd.firstVertex, drawCmd.vertexCount);
        glEnable(GL_DEPTH_TEST);
    }
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);

    // HUD
    glUseProgram(HUDShaderProgram);
    glDisable(GL_DEPTH_TEST);
    glActiveTexture(GL_TEXTURE0);
    
    hudWindowData := HUDWindowData.{clientDimensions = .{cast(float)refdef.clientWidth, cast(float)refdef.clientHeight}};
    // glBindBufferBase(GL_UNIFORM_BUFFER, 3, hudWindowDataUBO);

    glBindBuffer(GL_UNIFORM_BUFFER, hudWindowDataUBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(HUDWindowData), *hudWindowData, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    // ptr = glMapBuffer(GL_UNIFORM_BUFFER, GL_WRITE_ONLY);
    // memcpy(ptr, *hudWindowData, size_of(HUDWindowData));
    // glUnmapBuffer(GL_UNIFORM_BUFFER);

    // glBufferData(GL_UNIFORM_BUFFER, size_of(HUDWindowData), *hudWindowData, GL_STATIC_DRAW);    
    // glBindBuffer(GL_UNIFORM_BUFFER, 0);

    // glBindBufferBase(GL_UNIFORM_BUFFER, 2, hudTransformUBO);
    for i : 0..HUDDrawCount-1 {
        hudDrawCmd := refdef.HUDDrawList[i];
        hud := hudElements[hudDrawCmd.hudID];
        glBindVertexArray(hud.VAO);
        glBindTexture(GL_TEXTURE_2D, GetTextureHandleByID(hud.textureID));
        // glBindBuffer(GL_UNIFORM_BUFFER, hudTransformUBO); // glBindBufferBase seems to be enough.
        // glBufferData(GL_UNIFORM_BUFFER, size_of(HUDTransform), *hudDrawCmd.transform, GL_STATIC_DRAW);
        // glBindBuffer(GL_UNIFORM_BUFFER, 0);

        glBindBuffer(GL_UNIFORM_BUFFER, hudTransformUBO);
        glBufferData(GL_UNIFORM_BUFFER, size_of(HUDTransform), *hudDrawCmd.transform, GL_DYNAMIC_DRAW);
        glBindBuffer(GL_UNIFORM_BUFFER, 0);
        // ptr = glMapBuffer(GL_UNIFORM_BUFFER, GL_WRITE_ONLY);
        // memcpy(ptr, *hudDrawCmd.transform, size_of(HUDTransform));
        // glUnmapBuffer(GL_UNIFORM_BUFFER);

        glDrawArrays(GL_TRIANGLES, 0, xx hud.vertices.count);    
        
    }
    glEnable(GL_DEPTH_TEST);

    // Reset Entity count
    entityCount = 0;

    // Dont forget to clear the HUD drawlist!!!
    HUDDrawCount = 0;

    // Also, don't forget to reset the immediate 3D draw CMDs
    gImmediate3DDrawCmdCount = 0;

    SDL_GL_SwapWindow(refdef.window);
}