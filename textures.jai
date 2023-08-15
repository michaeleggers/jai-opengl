#import "Basic";
#import "String";
#import "stb_image";
#import "GL";

Texture :: struct {
    name : string;
    width, height, comp : s32;
    handle : GLuint;
};

textures : [..] Texture;

FlipImageVert :: (data : *u8, width : s32, height : s32, channels : s32) {
    bytesPerRow := width*channels;
    saveBottomRow := cast(*u8)alloc(bytesPerRow);
    start := 0;
    end := height-1;
    flips : u32 = cast(u32)height / 2 - 2;
    for 0..flips {
        startTop := data + start*bytesPerRow;
        startBottom := data + end*bytesPerRow;
        memcpy(saveBottomRow, startBottom, bytesPerRow);
        memcpy(startBottom, startTop, bytesPerRow);
        memcpy(startTop, saveBottomRow, bytesPerRow);
        start += 1;
        end -= 1;
    }
    free(saveBottomRow);
}

RegisterTexture :: (fileName : string) -> u32 {

    for textures {
        if !compare(fileName, it.name) {
            return xx it_index;
        }    
    }

    texture := Texture.{ name = fileName };
    texturePath := tprint("assets/textures/%", fileName);
    data := stbi_load(texturePath.data, *texture.width, *texture.height, *texture.comp, 0);    
    if !data {
        log("Failed to load texture: %\n", fileName, flags=.ERROR);
        exit(-1);
    }
    assert(texture.comp > 2, "Failed to load texture: %, too few components: %\n", fileName, texture.comp);
    print("Loaded texture-file: %, components: %\n", fileName, texture.comp);
    FlipImageVert(data, texture.width, texture.height, texture.comp); // Open GL UV y is bottom left...

    format : GLenum;
    internalFormat : GLint;
    if texture.comp == 3 {
        format = GL_RGB;
        internalFormat = GL_RGBA8;
    } else {
        format = GL_RGBA;
        internalFormat = GL_RGBA8;
    } 
    glGenTextures(1, *texture.handle);
    glBindTexture(GL_TEXTURE_2D, texture.handle);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, xx texture.width, xx texture.height, 0, format, GL_UNSIGNED_BYTE, data);

    stbi_image_free(data);

    array_add(*textures, texture);

    return xx (textures.count - 1);
}

GetTextureHandleByID :: (id : u32) -> GLuint {
    assert(id < textures.count);
    return textures[id].handle;
}