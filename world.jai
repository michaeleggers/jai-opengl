
gEntities : [..] Entity; // TODO: What is this?

World :: struct {
    models : [..] Model; // World geometry
    player : Entity;
    gravity := Vector3.{0.0, -0.01, 0.0}; // Applied on entities every frame that are set to react to gravity.
}

SpawnEntities :: (entities : [] Entity, refdef : *RefDef, world : *World) {
    for entity : entities {
        if entity.entityType == .PLAYER { // TODO: Actually load model data from disk and compute necessary stuff as AABB.
            world.player = entity;
            world.player.textureID = RegisterTexture(entity.texture);
            world.player.modelID = CreateEntityModel(GEOM_UNIT_CUBE);
            world.player.aabb = ComputeAABB(GEOM_UNIT_CUBE);
            world.player.currentAABB = world.player.aabb;
            world.player.pos = entity.pos;            
        }
    }
}

UpdateCameraOnMouse :: (camera : *Camera, dX : s32, dY : s32) {
    RotateAroundUp(camera, -dX * 0.01);
    RotateAroundSide(camera, -dY * 0.01);
}

ApplyGravity :: (world : *World, entity : *Entity) {
    entity.pos += world.gravity;
}

// TODO: This kinda does not belong here. Maybe put it somewhere in the renderer code
//       and just set a flag in refdef if AABBs should be drawn or not.
AABBlines : [12] Line;
UpdateWorld :: (keyState : [] bool, mouseState : MouseState, refdef : *RefDef, world : *World) {

    ApplyGravity(world, *world.player);
    UpdateOnKeys(*world.player, keyState);
    UpdateEntity(*world.player);
    
    // TODO: Make a polymorphic function that accepts entities and the camera.
    //       This function could be called something like 'ProcessKeyboardInput' and 'ProcessMouseInput'.
    //       The passed entity (or camera) brings a control-scheme, that defines what happens to this
    //       entity on certain key- (and mouse-) presses. So in the end, UpdateCameraOnKeys and
    //       UpdateCameraOnMouse are gone. Something like that.    
    if refdef.camera.type == Camera {
        UpdateOnKeys(refdef.camera, keyState);
        if mouseState.rightButtonDown {    
                UpdateCameraOnMouse(refdef.camera, mouseState.dX, mouseState.dY);
        }
    } else if refdef.camera.type == FollowCamera {
        UpdateFollowCamera(cast(*FollowCamera)refdef.camera);        
    }

    aabb := world.player.currentAABB;
    minX := aabb.minXYZ.x;
    minY := aabb.minXYZ.y;
    minZ := aabb.minXYZ.z;
    maxX := aabb.maxXYZ.x;
    maxY := aabb.maxXYZ.y;
    maxZ := aabb.maxXYZ.z;
    width := aabb.width;
    height := aabb.height;
    depth := aabb.depth;
    // We allocate memory here because returning an array of [12]Line lines will result in a stack overflow and crash.
    // AABBlines := cast(*Line)alloc(12 * size_of(Line));
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
    Draw3DImmediateLines(AABBlines); // TODO: This is probably the most C way of doing this. And it is... ugly. Maybe
    // we should just *not* use immediate draw for that many lines and just create a AABB VAO, VBO. Not sure...
    // And probably this draw call should not be here at all. lol.

    // free(AABBlines);

    // Add player entity to refresh definition
    RenderAddEntity(refdef, world.player);
}

