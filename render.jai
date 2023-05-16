#import "Basic";
#import "GL";
#import "SDL";
#import "Math";
#import "File";



VAO : GLuint;
VBO : GLuint;
totalVertexCount : u32;
UBO : GLuint;
shaderProgram : GLuint;
wireframeShaderProgram : GLuint;

models : [..] Model;

RefDef :: struct {
    clientWidth  : u32 = 1024;
    clientHeight : u32 = 768;
    window : *SDL_Window;
    camera : Camera;
    wireframe := false;
};

ViewProjMatrices :: struct {
    view := Matrix4_Identity;
    proj := Matrix4_Identity;
};

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
    shaderProgram = CreateShaderProgram("shaders/vert.glsl", "shaders/frag.glsl");
    wireframeShaderProgram = CreateShaderProgram("shaders/vert.glsl", "shaders/wireframe.frag");

    // VAO, VBO for Model data
    glGenVertexArrays(1, *VAO);
    glBindVertexArray(VAO);

    glGenBuffers(1, *VBO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    // Allocate enough space for 1024 quads
    glBufferData(GL_ARRAY_BUFFER,  1024 * 4 * size_of(Vertex), null, GL_STATIC_DRAW);    
    // glBindBuffer(GL_ARRAY_BUFFER, 0); // DANGEROUS: Unbinding at this point will lead to a desaster.

    // Input assembly for vertex shader
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), null);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)size_of(Vector3));
    glEnableVertexAttribArray(1);

    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(Vector3) + size_of(Vector2)));
    glEnableVertexAttribArray(2);

    // Per Frame Data (as of now: view proj matrices)
    glGenBuffers(1, *UBO);
    // glBindBuffer(GL_UNIFORM_BUFFER, UBO);
    // glBufferData(GL_UNIFORM_BUFFER, size_of(ViewProjMatrices), *viewProjMatrices, GL_STATIC_DRAW);
    // glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, UBO); // index (0) matches UBO binding ID in shader.
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

RegisterModel :: (model : *Model) -> u32 {
    lastVertexOffset := totalVertexCount * size_of(Vertex);
    
    glBindBuffer(GL_ARRAY_BUFFER, VBO);    
    glBufferSubData(GL_ARRAY_BUFFER, lastVertexOffset, model.vertices.count * size_of(Vertex), model.vertices.data);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    model.offset = totalVertexCount;
    totalVertexCount += xx model.vertices.count;
    array_add(*models, model);

    return xx (models.count - 1);
}

DrawFrame :: (refdef : RefDef) {
    viewProjMatrices : ViewProjMatrices;
    viewProjMatrices.view = CreateView(refdef.camera);
    viewProjMatrices.proj = Perspective(refdef.camera.fov * PI / 180.0, refdef.clientWidth / cast(float)refdef.clientHeight, 0.1, 1000.0);
    glBindBuffer(GL_UNIFORM_BUFFER, UBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(ViewProjMatrices), *viewProjMatrices, GL_STATIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);

    glViewport(0, 0, refdef.clientWidth, refdef.clientHeight);    

    glClearColor(0.5, 0.5, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glActiveTexture(GL_TEXTURE0);
    glBindVertexArray(VAO);    
    
    glUseProgram(shaderProgram);
    for models {
        // glEnable(GL_DEPTH_TEST);
        // glEnable(GL_CULL_FACE);        
        // glBindTexture(GL_TEXTURE_2D, GetTextureHandleByID(it.textureID));        
        // glDrawArrays(GL_TRIANGLES, xx it.offset, xx it.vertices.count);
        if refdef.wireframe {        
            glEnable(GL_CULL_FACE);            
            glEnable(GL_DEPTH_TEST);
            glUseProgram(wireframeShaderProgram);            
            glDrawArrays(GL_TRIANGLES, xx it.offset, xx it.vertices.count);
        }
    }    

    SDL_GL_SwapWindow(refdef.window);
}