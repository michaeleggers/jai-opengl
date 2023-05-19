#import "Basic";
#import "GL";
#import "SDL";
#import "Math";
#import "File";


// Vertex World data
totalVertexCount : u32; // TODO: Clean this up. Should be part of the batch struct. But doesn't work without it. Figure out why...

// Uniform Buffers
viewProjectionUBO : GLuint;
perFrameSettingsUBO : GLuint;

// Shaders
shaderProgram : GLuint;
wireframeShaderProgram : GLuint;

batches : [..] Batch;

RefDef :: struct {
    clientWidth  : u32 = 1024;
    clientHeight : u32 = 768;
    window : *SDL_Window;
    camera : Camera;
    wireframe := false;
};

Batch :: struct {
    VAO, VBO         : GLuint;
    textureID        : u32;
    totalVertexCount : u32;
    vertices         : [..] Vertex;
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

    // Allocate enough space for 1024 quads
    glBufferData(GL_ARRAY_BUFFER, 1024 * 4 * size_of(Vertex), null, GL_STATIC_DRAW);

    array_add(*batches, result);

    return *batches[batches.count - 1];
}

ViewProjMatrices :: struct {
    view := Matrix4_Identity;
    proj := Matrix4_Identity;
};

PerFrameSettings :: struct {
    drawWireframe : u32 = 0;
}

RenderPrepare :: () {
    // Some general GL settings. Must be set BEFORE SDL creates the OpenGL context!
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
}

// TODO: Are there namespaces? Or do we have to prefix stuff? Because we could have just Render::Init(), maybe?
RenderInit :: () {

    // Load GL function pointers
    gl_load(*gl, SDL_GL_GetProcAddress);
    using gl; // TODO: Why? This is not really needed?

    print("GL Vendor = %\n", to_string(glGetString(GL_VENDOR)));
    print("GL Version = %\n", to_string(glGetString(GL_VERSION)));

    // Set GL states
    glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glCullFace(GL_BACK);
    glFrontFace(GL_CCW);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Shaders
    shaderProgram = CreateShaderProgram("shaders/basic_world.vert", "shaders/basic_world.frag");
    wireframeShaderProgram = CreateShaderProgram("shaders/basic_world.vert", "shaders/wireframe.frag");

    // Per Frame Data (as of now: view proj matrices)
    uniformBuffers : [2] *GLuint;
    uniformBuffers[0] = *viewProjectionUBO;
    uniformBuffers[1] = *perFrameSettingsUBO;
    glGenBuffers(xx uniformBuffers.count, uniformBuffers[0]);
    // glBindBuffer(GL_UNIFORM_BUFFER, UBO);
    // glBufferData(GL_UNIFORM_BUFFER, size_of(ViewProjMatrices), *viewProjMatrices, GL_STATIC_DRAW);
    // glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, viewProjectionUBO); // index (0) matches UBO binding ID in shader.
    glBindBufferBase(GL_UNIFORM_BUFFER, 1, perFrameSettingsUBO);
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
    glAttachShader(shaderProgram, vertShader);
    glAttachShader(shaderProgram, fragShader);
    glLinkProgram(shaderProgram);
    linkStatus : GLint;
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, *linkStatus);
    if !linkStatus {
        logData : [1024] u8;
        glGetShaderInfoLog(shaderProgram, logData.count, null, logData.data);
        log("Failed to link shader program:\n%\n", to_string(logData.data), flags=.ERROR);
        exit(-1);
    }

    return shaderProgram;
}

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
    dataSize := model.tris.count * size_of(Tri);

    glBindBuffer(GL_ARRAY_BUFFER, batch.VBO);    
    glBufferSubData(GL_ARRAY_BUFFER, lastVertexOffset, dataSize, model.tris.data);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    batch.totalVertexCount += xx (model.tris.count * 3);    
}

DrawFrame :: (refdef : RefDef) {
    viewProjMatrices : ViewProjMatrices;
    viewProjMatrices.view = CreateView(refdef.camera);
    viewProjMatrices.proj = Perspective(refdef.camera.fov * PI / 180.0, refdef.clientWidth / cast(float)refdef.clientHeight, 0.1, 1000.0);
    glBindBuffer(GL_UNIFORM_BUFFER, viewProjectionUBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(ViewProjMatrices), *viewProjMatrices, GL_STATIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    // Can this check syntactically be more concise?
    perFrameSettings : PerFrameSettings;
    if refdef.wireframe {
        perFrameSettings.drawWireframe = 1;
    } else {
        perFrameSettings.drawWireframe = 0;
    }
    glBindBuffer(GL_UNIFORM_BUFFER, perFrameSettingsUBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(PerFrameSettings), *perFrameSettings, GL_STATIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    glViewport(0, 0, refdef.clientWidth, refdef.clientHeight);    

    glClearColor(0.5, 0.5, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glActiveTexture(GL_TEXTURE0);
    
    glUseProgram(shaderProgram);
    for batches {
        glBindVertexArray(it.VAO);    
        // glBindBuffer(GL_ARRAY_BUFFER, it.VBO);
        glBindTexture(GL_TEXTURE_2D, GetTextureHandleByID(it.textureID));
        glDrawArrays(GL_TRIANGLES, 0, xx it.vertices.count);
    }
    // for models {
    //     // glEnable(GL_DEPTH_TEST);
    //     // glEnable(GL_CULL_FACE);        
    //     glBindTexture(GL_TEXTURE_2D, GetTextureHandleByID(it.textureID));        
    //     glDrawArrays(GL_TRIANGLES, xx it.offset, xx it.vertices.count);
    // }    

    SDL_GL_SwapWindow(refdef.window);
}