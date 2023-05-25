EntityType :: enum u32 {
    PLAYER;
}

Entity :: struct {
    type        : EntityType;
    pos         : Vector3;
    orientation : Quaternion;
}

