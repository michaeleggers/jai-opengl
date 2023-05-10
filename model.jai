#import "Basic";
#import "Math";
#import "File";

Vertex :: struct {
    pos : Vector3;
    uv  : Vector2;
}

Model :: struct {
    vertices : [..] Vertex;
    position : Vector3;
    modelMat := Matrix4_Identity;
}
