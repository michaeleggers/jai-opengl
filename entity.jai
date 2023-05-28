EntityType :: enum u32 {
    PLAYER;
}

AABB :: struct {
    minXYZ := Vector3.{-1.0, -1.0, -1.0};
    maxXYZ := Vector3.{1.0, 1.0, 1.0};
    width : float = 2;
    height : float = 2;
    depth : float = 2;
    debugLines : *Line; // Lines for rendering view of this aabb. It should be [12]Line but that results in a stack overflow right at startup.
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

    // We allocate memory here because returning an array of [12]Line lines will result in a stack overflow and crash.
    AABBlines := cast(*Line)alloc(12 * size_of(Line));
    AABBlines[0] = .{
            a = .{pos = .{minX, minY, minZ}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{minX + width, minY, minZ}, color = .{1.0, 1.0, 1.0}} 
    };
    AABBlines[1] = .{
            a = .{pos = .{minX, minY, minZ}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{minX, minY + height, minZ}, color = .{1.0, 1.0, 1.0}} 
    };
    AABBlines[2] = .{
            a = .{pos = .{minX, minY, minZ}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{minX, minY, minZ + depth}, color = .{1.0, 1.0, 1.0}} 
    };
    AABBlines[3] = .{
            a = .{pos = .{maxX, maxY, maxZ}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{maxX - width, maxY, maxZ}, color = .{1.0, 1.0, 1.0}} 
    };
    AABBlines[4] = .{
            a = .{pos = .{maxX, maxY, maxZ}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{maxX, maxY - height, maxZ}, color = .{1.0, 1.0, 1.0}} 
    };
    AABBlines[5] = .{
            a = .{pos = .{maxX, maxY, maxZ}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{maxX, maxY, maxZ - depth}, color = .{1.0, 1.0, 1.0}} 
    };
    AABBlines[6] = .{
            a = .{pos = .{maxX, maxY, maxZ - depth}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{minX, minY + height, minZ}, color = .{1.0, 1.0, 1.0}},
    };
    AABBlines[7] = .{
            a = .{pos = .{minX, minY + height, minZ}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{maxX - width, maxY, maxZ}, color = .{1.0, 1.0, 1.0}}
    };
    AABBlines[8] = .{
            a = .{pos = .{maxX - width, maxY, maxZ}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{minX, minY, minZ + depth}, color = .{1.0, 1.0, 1.0}} 
    };
    AABBlines[9] = .{
            a = .{pos = .{minX, minY, minZ + depth}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{maxX, maxY - height, maxZ}, color = .{1.0, 1.0, 1.0}} 
    };
    AABBlines[10] = .{
            a = .{pos = .{maxX, maxY - height, maxZ}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{minX + width, minY, minZ}, color = .{1.0, 1.0, 1.0}}
    };
    AABBlines[11] = .{
            a = .{pos = .{minX + width, minY, minZ}, color = .{1.0, 1.0, 1.0}},
            b = .{pos = .{maxX, maxY, maxZ - depth}, color = .{1.0, 1.0, 1.0}}
    };

    aabb := AABB.{
        minXYZ = .{minX, minY, minZ},
        maxXYZ = .{maxX, maxY, maxZ},
        width = width, height = height, depth = depth,    
        debugLines = AABBlines
    };
    // memcpy(aabb.debugLines.data, AABBlines.data, 12 * size_of(Line));

    return aabb;
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

