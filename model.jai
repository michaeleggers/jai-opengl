#import "Basic";
#import "Math";

Vertex :: struct {
    pos     : Vector3;
    uv      : Vector2;
    bc      : Vector3;
    normal  : Vector3;
}

Tri :: struct {
    a, b, c : Vertex;
}

Model :: struct {
    tris        : [..] Tri;
    position    : Vector3;
    modelMat    := Matrix4_Identity;
    textureID   : u32;
    offset      : u32;
}
