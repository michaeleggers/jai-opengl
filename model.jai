#import "Basic";
#import "Math";

Vertex :: struct {
    pos : Vector3;
    uv  : Vector2;
    bc  : Vector3;
}

Model :: struct {
    vertices    : [..] Vertex;
    position    : Vector3;
    modelMat    := Matrix4_Identity;
    textureID   : u32;
    offset      : u32;
}
