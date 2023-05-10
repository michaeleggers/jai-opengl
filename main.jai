#import "Basic";
#import "SDL";
#import "GL";
#import "File";
#import "Math";

#import, file "model.jai";
#import, file "camera.jai";
#import, file "textures.jai";

RefDef :: struct {
    clientWidth  : u32 = 1024;
    clientHeight : u32 = 768;
};

ViewProjMatrices :: struct {
    view := Matrix4_Identity;
    proj := Matrix4_Identity;
};

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

main :: () {

    if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
        print("SDL Init Error: %\n", to_string(SDL_GetError()));
        return;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

    refdef : RefDef;

    window := SDL_CreateWindow("Jai SDL-OpenGL",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        xx refdef.clientWidth, xx refdef.clientHeight,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);

    if (!window) {
        print("SDL CreateWindow Error: %\n", to_string(SDL_GetError()));
        return;
    }
    
    sdlGlContext := SDL_GL_CreateContext(window);
    if (!sdlGlContext) {
        print("SDL GL_CreateContext Error: %\n", to_string(SDL_GetError()));
        return;
    }

    gl_load(*gl, SDL_GL_GetProcAddress);
    using gl;

    print("GL Vendor = %\n", to_string(glGetString(GL_VENDOR)));
    print("GL Version = %\n", to_string(glGetString(GL_VERSION)));

    // Shaders
    shaderProgram := CreateShaderProgram("shaders/vert.glsl", "shaders/frag.glsl");

    // Model Data
    vertices := Vertex.[
        .{pos = .{-1.0, -1.0, 0.0}, uv = .{0.0, 0.0}},
        .{pos = .{ 1.0, -1.0, 0.0}, uv = .{1.0, 0.0}},
        .{pos = .{ 0.0, 1.0, 0.0},  uv = .{0.5, 1.0}}
    ];
    triangle := Model.{ position = .{0.0, 0.0, 0.0}};
    for vertices array_add(*triangle.vertices, it);

    // VAO, VBO for Model data
    VAO : GLuint;
    glGenVertexArrays(1, *VAO);
    glBindVertexArray(VAO);

    VBO : GLuint;
    glGenBuffers(1, *VBO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, triangle.vertices.count * size_of(Vertex), triangle.vertices.data, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), null);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)size_of(Vector3));
    glEnableVertexAttribArray(1);

    // Load some textures
    woodPlankTex := createTexture("assets/textures/wood_planks_01.tga");
    print("Wood Planks Texture: %\n", woodPlankTex);

    // Uniform Buffer Object for view projection
    camera := Camera.{pos = .{0.0, 0.0, 2.0}}; // Move cam 'back' a little bit (+z comes out of the monit... OUCH!)
    viewProjMatrices : ViewProjMatrices;
    // Transpose matrices, because Math module is row major. But OpenGL works with col-major by default.
    viewProjMatrices.view = transpose(createView(*camera));
    viewProjMatrices.proj = transpose(make_projection_matrix(90.0 * PI / 180.0, refdef.clientWidth / cast(float)refdef.clientHeight, 0.1, 1000.0));
    UBO : GLuint;
    glGenBuffers(1, *UBO);
    glBindBuffer(GL_UNIFORM_BUFFER, UBO);
    glBufferData(GL_UNIFORM_BUFFER, size_of(ViewProjMatrices), *viewProjMatrices, GL_STATIC_DRAW);
    glBindBuffer(GL_UNIFORM_BUFFER, 0);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, UBO); // index (0) matches UBO binding ID in shader.

    // Set GL state
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glFrontFace(GL_CCW);
    glEnable(GL_DEPTH_TEST);

    // Program is static for this test
    glUseProgram(shaderProgram);

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

        viewProjMatrices.view = transpose(createView(*camera));
        viewProjMatrices.proj = transpose(make_projection_matrix(90.0 * PI / 180.0, refdef.clientWidth / cast(float)refdef.clientHeight, 0.1, 1000.0));
        glBindBuffer(GL_UNIFORM_BUFFER, UBO);
        glBufferData(GL_UNIFORM_BUFFER, size_of(ViewProjMatrices), *viewProjMatrices, GL_STATIC_DRAW);
        glBindBuffer(GL_UNIFORM_BUFFER, 0);

        glViewport(0, 0, refdef.clientWidth, refdef.clientHeight);

        glClearColor(0.5, 0.5, 1.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, woodPlankTex.handle);
        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLES, 0, xx triangle.vertices.count);

        SDL_GL_SwapWindow(window);
    }

    SDL_DestroyWindow(window);
    SDL_Quit();

}