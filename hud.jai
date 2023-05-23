#import "Basic";

crosshairTexture : Texture;

CHUDElement :: struct {
    id        : u32; // ID is index into the HUDElements array in render.jai. TODO: Gets assigned through model
}

CreateHUD :: (file : string) -> CHUDElement {    
    id := RegisterTexture(file);
    model : Model;
    for tri : GEOM_QUAD {
        array_add(*model.tris, tri);
    }
    model.textureID = id;
    RegisterHUD(*model);
    
    result := CHUDElement.{id = model.hudID};
    return result;
}

