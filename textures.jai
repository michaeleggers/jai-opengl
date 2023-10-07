#import "Basic";
#import "String";
#import "stb_image";
#import "GL";

#scope_file

textures : [..] Texture;

#scope_export

Texture :: struct {
    name : string;
    width, height, comp : s32;
    handle : GLuint;
};


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

FindTextureFileOnDisk :: (name : string) -> bool, string {
    
    if name[name.count-4] == #char "." {
        file := tprint("assets/textures/%", name);
        if file_exists(file) return true, file;
    }    

    extensions := string.["tga", "png"];
    for extensions {
        file := tprint("assets/textures/%.%", name, it);
        if file_exists(file) return true, file;
    }

    return false, name;
}

RegisterTexture :: (fileName : string) -> u32 {

    for textures {
        if !compare(fileName, it.name) {
            return xx it_index;
        }    
    }

    texture := Texture.{ name = fileName };

    found, pathAndFileName := FindTextureFileOnDisk(fileName);
    if !found {
        log("Failed to load texture: %\n", pathAndFileName, flags=.ERROR);
        exit(-1);
    }

    // TODO: ToCString allocs and is never freed! Can we make it operate on stack memory?
    data := stbi_load(ToCString(pathAndFileName), *texture.width, *texture.height, *texture.comp, 0);        
    if !data {
        log("stbi_load failed to load texture: %\n", pathAndFileName, flags=.ERROR);
        exit(-1);
    }
    assert(texture.comp > 2, "Failed to load texture: %, too few components: %\n", fileName, texture.comp);

    print("Loaded texture-file: %, components: %\n", fileName, texture.comp);
    FlipImageVert(data, texture.width, texture.height, texture.comp); // Open GL UV y=0 is bottom left...

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

GetTextureByName :: (name : string) -> Texture, bool {
    GetTextureID :: (name : string) -> s64 {
        for textures {
            if !compare(name, it.name) {
                return xx it_index;
            }
        }        
        return -1;
    }

    id := GetTextureID(name);
    if id < 0 return .{}, false;

    return textures[id], true;
}