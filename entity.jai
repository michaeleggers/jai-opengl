
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
        }
    };
    type        : EntityType;
    pos         : Vector3;
    orientation : Quaternion;
    aabb        : AABB;    
    currentAABB : AABB;
    modelID     : u32; // ID into entity model array in render.jai
    textureID   : u32;
    texture     : string; // TODO: actually when processing entities in a loop, I don't really want that here!
    transform   := Matrix4_Identity; // Holds the current transformation matrix    
    followCamera : *FollowCamera = null;
}

AABB :: struct {
    minXYZ := Vector3.{-1.0, -1.0, -1.0};
    maxXYZ := Vector3.{1.0, 1.0, 1.0};
    width : float = 2;
    height : float = 2;
    depth : float = 2;
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

    return .{
        minXYZ = .{minX, minY, minZ},
        maxXYZ = .{maxX, maxY, maxZ},
        width = width, height = height, depth = depth,    
    };
}

UpdateEntity :: (entity : *Entity) { // TODO: Find out how to do namespaces (if they exist or if there is something like it)
    // update transform matrix
    entity.transform = transpose(make_translation_matrix4(entity.pos));    

    // apply that transform to AABB. We need it on CPU side for collision detection
    minXYZ := Mat4XVec4(entity.transform, vec3toVec4(entity.aabb.minXYZ));
    maxXYZ := Mat4XVec4(entity.transform, vec3toVec4(entity.aabb.maxXYZ));
    entity.currentAABB.minXYZ = .{minXYZ.x, minXYZ.y, minXYZ.z};
    entity.currentAABB.maxXYZ = .{maxXYZ.x, maxXYZ.y, maxXYZ.z};    
}

