#import "Basic";
#import "Math";

Vertex :: struct {
    pos     : Vector3;
    uv      : Vector2;
    bc      : Vector3;
    normal  : Vector3;
    color   := Vector3.{1.0, 1.0, 1.0};
    blendindices : [4] u32;
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

// A WorldTri is very similar to a regular Tri but it is used for static world
// geometry or what is called *brush entities* in Quake: World geometry that
// has some kind of behaviour, like doors, elevators, buttons, etc...
// A WorldTri also can have some surface-flags that tells us what
// kind of sound should be played when the player walks over it.
// Or even transparancy settings for the renderer.
// WorldTris are batched by there TextureID for now to
// reduce the amount of draw-calls for the renderer.

WorldTri :: struct {
    a, b, c : Vertex;    

    textureID : u32;

    #place a; vertices : [3] Vertex;
}