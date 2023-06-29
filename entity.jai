
EntityType :: enum u32 {
    PLAYER;
}

Entity :: struct {
    #as using base := BaseEntity.{    
        VirtualUpdateOnKeys = (baseEntity : *BaseEntity, keyState : [] bool) {
            using cast(*Entity)baseEntity;
            if keyState[SDLK_h] pos.x += 0.01;
            if keyState[SDLK_f] pos.x -= 0.01;
            if keyState[SDLK_t] pos.z -= 0.01;
            if keyState[SDLK_g] pos.z += 0.01;   
            if keyState[SDLK_i] pos.y += 0.1;  // A bit more than gravity force so we can "jump"
            if keyState[SDLK_k] pos.y -= 0.01;   

        }
    };
    entityType   : EntityType;
    pos          : Vector3;
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

AABB :: struct {
    minXYZ := Vector3.{-1.0, -1.0, -1.0};
    maxXYZ := Vector3.{1.0, 1.0, 1.0};
    width : float = 2;
    height : float = 2;
    depth : float = 2;    

    // All 8 points of the box, not sure if this is a waste of memory...
    // but makes collision detection easier. TODO: How does Quake do it?
    bottomA := Vector3.{-1.0, -1.0, -1.0}; // minXYZ, TODO: Alias in structs?
    bottomB := Vector3.{-1.0, -1.0, 1.0};
    bottomC := Vector3.{ 1.0, -1.0, 1.0};
    bottomD := Vector3. {1.0, -1.0, -1.0};

    topA := Vector3.{-1.0, 1.0, -1.0};
    topB := Vector3.{-1.0, 1.0,  1.0};
    topC := Vector3.{ 1.0, 1.0,  1.0}; // maxXYZ, TODO: Alias  in structs?
    topD := Vector3.{ 1.0, 1.0, -1.0};
}

// Should maybe be in math graphics or collision.jai or something...
ComputeAABB :: (tris : [] Tri) -> AABB {
    minX, minY, minZ : float = 999.99;
    maxX, maxY, maxZ : float = -999.99;
    for tri : tris {
        pos := tri.a.pos;
        if      pos.x < minX minX = pos.x;
        else if pos.x > maxX maxX = pos.x;
        if      pos.y < minY minY = pos.y;
        else if pos.y > maxY maxY = pos.y;
        if      pos.z < minZ minZ = pos.z;
        else if pos.z > maxZ maxZ = pos.z;        

        pos = tri.b.pos;
        if      pos.x < minX minX = pos.x;
        else if pos.x > maxX maxX = pos.x;
        if      pos.y < minY minY = pos.y;
        else if pos.y > maxY maxY = pos.y;
        if      pos.z < minZ minZ = pos.z;
        else if pos.z > maxZ maxZ = pos.z;        

        pos = tri.c.pos;
        if      pos.x < minX minX = pos.x;
        else if pos.x > maxX maxX = pos.x;
        if      pos.y < minY minY = pos.y;
        else if pos.y > maxY maxY = pos.y;
        if      pos.z < minZ minZ = pos.z;
        else if pos.z > maxZ maxZ = pos.z;
    }
    width := abs(maxX - minX);
    height := abs(maxY - minY);
    depth := abs(maxZ - minZ);

    X := Vector3.{1.0, 0.0, 0.0};
    Y := Vector3.{0.0, 1.0, 0.0};
    Z := Vector3.{0.0, 0.0, 1.0};
    minXYZ := Vector3.{minX, minY, minZ};
    maxXYZ := Vector3.{maxX, maxY, maxZ};
    bottomA := minXYZ;
    bottomB := minXYZ + Z*depth;
    bottomC := bottomB + X*width;
    bottomD := bottomA + X*width;
    topA := maxXYZ;
    topB := bottomB + Y*height;
    topC := bottomC + Y*height;
    topD := bottomD + Y*height;
    
    return .{
        minXYZ,
        maxXYZ,
        width, height, depth,
        bottomA, bottomB, bottomC, bottomD,
        topA, topB, topC, topD
    };
}

// TODO: THIS IS REALLY UGLY!!!
UpdateEntity :: (entity : *Entity) { // TODO: Find out how to do namespaces (if they exist or if there is something like it)
    // update transform matrix
    entity.transform = transpose(make_translation_matrix4(entity.pos));    

    // apply that transform to AABB. We need it on CPU side for collision detection
    minXYZ := Mat4XVec4(entity.transform, vec3toVec4(entity.aabb.minXYZ));
    maxXYZ := Mat4XVec4(entity.transform, vec3toVec4(entity.aabb.maxXYZ));
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
    entity.currentAABB.topA = maxXYZ3;
    entity.currentAABB.topB = entity.currentAABB.bottomB + Y*height;
    entity.currentAABB.topC = entity.currentAABB.bottomC + Y*height;
    entity.currentAABB.topD = entity.currentAABB.bottomD + Y*height;
}

