#import "Basic";
#import "Math";

Vertex :: struct {
    pos     : Vector3;
    uv      : Vector2;
    bc      : Vector3;
    normal  : Vector3;
    color   := Vector3.{1.0, 1.0, 1.0};
    blendindices : [4] u8;
    blendweights : Vector4;
}

Tri :: struct {
    a, b, c : Vertex;
    
    #place a; vertices : [3] Vertex;
}

Line :: struct {
    a, b : Vertex;
}

Model :: struct {
    tris        : [..] Tri;
    position    : Vector3;
    modelMat    := Matrix4_Identity;
    textureID   : u32;
    offset      : u32;
    aabb        : AABB;

    // Only for HUD elements. ID is index into the HUDElements array in render.jai
    hudID       : u32;
}
