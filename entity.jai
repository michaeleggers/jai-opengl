
EntityType :: enum u32 {
    PLAYER;
}

Entity :: struct {
    #as using base := BaseEntity.{    
        VirtualUpdateOnKeys = (baseEntity : *BaseEntity, keyState : [] bool) {
            using cast(*Entity)baseEntity;
            if keyState[SDLK_h] predict.x += 0.01;
            if keyState[SDLK_f] predict.x -= 0.01;
            if keyState[SDLK_t] predict.z -= 0.01;
            if keyState[SDLK_g] predict.z += 0.01;   
            if keyState[SDLK_i] predict.y += 0.1080;  // A bit more than gravity force so we can "jump"
            if keyState[SDLK_k] predict.y -= 0.07;   

        }
    };
    entityType   : EntityType;
    pos          : Vector3;
    predict      : Vector3;
    orientation  : Quaternion;
    aabb         : AABB;    
    currentAABB  : AABB;
    modelID      : u32; // ID into entity model array in render.jai
    textureID    : u32;
    texture      : string; // TODO: actually when processing entities in a loop, I don't really want that here!
    transform    := Matrix4_Identity; // Holds the current transformation matrix    
    followCamera : *FollowCamera = null;
    applyGravity := true; // By default the world's gravity force is applied every frame.
}

// TODO: THIS IS REALLY UGLY!!!
UpdateEntity :: (entity : *Entity) { // TODO: Find out how to do namespaces (if they exist or if there is something like it)
    // update transform matrix
    entity.transform = transpose(make_translation_matrix4(entity.pos));    

    // apply that transform to AABB. We need it on CPU side for collision detection
    minXYZ := Mat4XVec4(entity.transform, vec3toVec4(entity.aabb.minXYZ));
    maxXYZ := Mat4XVec4(entity.transform, vec3toVec4(entity.aabb.maxXYZ));

    // NOTE: The extents *could* change. Account for that in the future...
    width := entity.aabb.width;
    height := entity.aabb.height;
    depth := entity.aabb.depth;

    X := Vector3.{1.0, 0.0, 0.0};
    Y := Vector3.{0.0, 1.0, 0.0};
    Z := Vector3.{0.0, 0.0, 1.0};
    minXYZ3 := Vector3.{minXYZ.x, minXYZ.y, minXYZ.z};
    maxXYZ3 := Vector3.{maxXYZ.x, maxXYZ.y, maxXYZ.z};
    entity.currentAABB.minXYZ = minXYZ3;
    entity.currentAABB.maxXYZ = maxXYZ3; 
    entity.currentAABB.bottomA = minXYZ3;
    entity.currentAABB.bottomB = minXYZ3 + Z*depth;
    entity.currentAABB.bottomC = entity.currentAABB.bottomB + X*width;
    entity.currentAABB.bottomD = entity.currentAABB.bottomA + X*width;
    entity.currentAABB.topA = entity.currentAABB.bottomA + Y*height;
    entity.currentAABB.topB = entity.currentAABB.bottomB + Y*height;
    entity.currentAABB.topC = entity.currentAABB.bottomC + Y*height;
    entity.currentAABB.topD = entity.currentAABB.bottomD + Y*height;

    Draw3DAABB(entity.currentAABB);
    
    entity.predict = .{0.0, 0.0, 0.0};
}

