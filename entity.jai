EntityType :: enum u32 {
    PLAYER;
}

AABB :: struct {
    minXYZ := Vector3.{-1.0, -1.0, -1.0};
    maxXYZ := Vector3.{1.0, 1.0, 1.0};
}

Entity :: struct {
    type        : EntityType;
    pos         : Vector3;
    orientation : Quaternion;
    aabb        : AABB;    
    modelID     : u32; // ID into entity model array in render.jai
    textureID   : u32;
    texture     : string; // TODO: actually when processing entities in a loop, I don't really want that here!
}

