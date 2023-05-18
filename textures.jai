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

RegisterTexture :: (fileName : string) -> u32 {

    for textures {
        if !compare(fileName, it.name) {
            return xx it_index;
        }    
    }

    texture := Texture.{ name = fileName };
    texturePath := tprint("assets/textures/%", fileName);
    data := stbi_load(texturePath.data, *texture.width, *texture.height, *texture.comp, 4);    
    if !data {
        log("Failed to load texture: %\n", fileName, flags=.ERROR);
        exit(-1);
    }

    glGenTextures(1, *texture.handle);
    glBindTexture(GL_TEXTURE_2D, texture.handle);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx texture.width, xx texture.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);

    stbi_image_free(data);

    array_add(*textures, texture);

    return xx (textures.count - 1);
}

GetTextureHandleByID :: (id : u32) -> GLuint {
    assert(id < textures.count);
    return textures[id].handle;
}