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
}

