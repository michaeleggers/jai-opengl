#import "Basic";
#import "stb_image";
#import "GL";

Texture :: struct {
    name : string;
    width, height, comp : s32;
    handle : GLuint;
};

createTexture :: (fileName : string) -> Texture {
    texture := Texture.{ name = fileName };
    data := stbi_load(fileName.data, *texture.width, *texture.height, *texture.comp, 4);    
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

    return texture;
}