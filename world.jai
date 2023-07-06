
gEntities : [..] Entity; // TODO: What is this?

World :: struct {
    models : [..] Model; // World geometry
    player : Entity;
    gravity := Vector3.{-0.001, -0.07, 0.001}; // Applied on entities every frame that are set to react to gravity.
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

SweepAABB :: (aabb : AABB, sweep : Vector3) -> AABB, AABB, AABB {
    maxXYZ_x := aabb.maxXYZ;
    maxXYZ_x.x += sweep.x;
    sweptAABB_x : AABB;
    if sweep.x > 0 {
        sweptAABB_x.minXYZ = aabb.minXYZ;
        sweptAABB_x.maxXYZ = maxXYZ_x;
    } else {
        maxXYZ_x = aabb.minXYZ;
        maxXYZ_x.x += sweep.x;
        sweptAABB_x.minXYZ = maxXYZ_x;
        sweptAABB_x.maxXYZ = aabb.maxXYZ;
    }

    maxXYZ_y := aabb.maxXYZ;
    maxXYZ_y.y += sweep.y;
    sweptAABB_y : AABB;
    if sweep.y > 0 {
        sweptAABB_y.minXYZ = aabb.minXYZ;
        sweptAABB_y.maxXYZ = maxXYZ_y;
    } else {
        maxXYZ_y = aabb.minXYZ;
        maxXYZ_y.y += sweep.y;
        sweptAABB_y.minXYZ = maxXYZ_y;
        sweptAABB_y.maxXYZ = aabb.maxXYZ;
    }

    maxXYZ_z := aabb.maxXYZ;
    maxXYZ_z.z += sweep.z;
    sweptAABB_z : AABB;
    if sweep.z > 0 {
        sweptAABB_z.minXYZ = aabb.minXYZ;
        sweptAABB_z.maxXYZ = maxXYZ_z;
    } else {
        maxXYZ_z = aabb.minXYZ;
        maxXYZ_z.z += sweep.z;
        sweptAABB_z.minXYZ = maxXYZ_z;
        sweptAABB_z.maxXYZ = aabb.maxXYZ;
    }

    return sweptAABB_x, sweptAABB_y, sweptAABB_z;
}

MoveAABB :: (aabb : AABB, velocity : Vector3, models : [] Model) -> Vector3 {
    startBA := aabb.bottomA;
    startBB := aabb.bottomB;
    startBC := aabb.bottomC;
    startBD := aabb.bottomD;
    startTA := aabb.topA;
    startTB := aabb.topB;
    startTC := aabb.topC;
    startTD := aabb.topD;
    endBA := startBA + velocity;
    endBB := startBB + velocity;
    endBC := startBC + velocity;
    endBD := startBD + velocity;
    endTA := startTA + velocity;
    endTB := startTB + velocity;
    endTC := startTC + velocity;
    endTD := startTD + velocity;
    max := length(velocity);

    hitList : [8] HitRecord;
    hitList[0] = Trace(startBA, startBA + velocity, max, models);
    hitList[1] = Trace(startBB, startBB + velocity, max, models);
    hitList[2] = Trace(startBC, startBC + velocity, max, models);
    hitList[3] = Trace(startBD, startBD + velocity, max, models);
    hitList[4] = Trace(startTA, startTA + velocity, max, models);
    hitList[5] = Trace(startTB, startTB + velocity, max, models);
    hitList[6] = Trace(startTC, startTC + velocity, max, models);
    hitList[7] = Trace(startTD, startTD + velocity, max, models);

    dir := normalize(velocity);
    shortestDistance := max;        
    for hitList {
        if it.success {                                    
            if it.distance < shortestDistance {
                shortestDistance = it.distance;
            }
        }
    }    
    // Avoid to penetrate completely so we don't get stuck in geometry.
    bias := 0.000001;
    correction : Vector3;
    if shortestDistance < bias {
        correction = bias*(-dir);
    }

    movement := shortestDistance*dir + correction;    
    print("correction: %\n", correction);

    return movement;
}

// TODO: Do I need a physics.jai?
// TODO: This stuff is probably very expensive!!!
ApplyGravity :: (keyState : [] bool, world : *World, entity : *Entity) {
    // Sweep bounding box
    startBA := entity.currentAABB.bottomA;
    startBB := entity.currentAABB.bottomB;
    startBC := entity.currentAABB.bottomC;
    startBD := entity.currentAABB.bottomD;
    startTA := entity.currentAABB.topA;
    startTB := entity.currentAABB.topB;
    startTC := entity.currentAABB.topC;
    startTD := entity.currentAABB.topD;
    endBA := startBA + world.gravity;
    endBB := startBB + world.gravity;
    endBC := startBC + world.gravity;
    endBD := startBD + world.gravity;
    endTA := startTA + world.gravity;
    endTB := startTB + world.gravity;
    endTC := startTC + world.gravity;
    endTD := startTD + world.gravity;

    sweptAABB_x, sweptAABB_y, sweptAABB_z := SweepAABB(entity.currentAABB, world.gravity);
    // sweptAABB_x := AABB.{
    //     minXYZ = entity.currentAABB.minXYZ,
    //     maxXYZ = maxXYZ_x
    // };

    // check AABB overlap with world geometry        
    worldCollisionModels : [..] Model;
    for world.models {    
        if CheckAABB(sweptAABB_x, it.aabb) {
            array_add(*worldCollisionModels, it);            
        }
        if CheckAABB(sweptAABB_y, it.aabb) {
            array_add(*worldCollisionModels, it);            
        }
        if CheckAABB(sweptAABB_z, it.aabb) {
            array_add(*worldCollisionModels, it);            
        }
    }

    // Trace rays
    start := entity.currentAABB.maxXYZ;
    if world.gravity.x < 0 {
        start.x = entity.currentAABB.minXYZ.x;
    }
    if world.gravity.y < 0 {
        start.y = entity.currentAABB.minXYZ.y;
    }
    if world.gravity.z < 0 {
        start.z = entity.currentAABB.minXYZ.z;
    }
    end := start + world.gravity;
    dir := normalize(world.gravity);
    max := length(world.gravity);
    rayVis : [1] Line;
    rayVis[0] = .{
        a = .{pos = start, color = .{1.0, 1.0, 1.0}},
        b = .{pos = start + max*dir, color = .{1.0, 1.0, 1.0}}
    };
    Draw3DImmediateLines(rayVis);

    // print("start: %, end: %\n", start, end);
    movement := MoveAABB(entity.currentAABB, Vector3.{1.0, 0.0, 0.0} * world.gravity, worldCollisionModels);    
    movement += MoveAABB(entity.currentAABB, Vector3.{0.0, 1.0, 0.0} * world.gravity, worldCollisionModels);
    movement += MoveAABB(entity.currentAABB, Vector3.{0.0, 0.0, 1.0} * world.gravity, worldCollisionModels);


    // Draw all world models that the player collided with     
    for worldCollisionModels { 
        Draw3DAABB(it.aabb);        
    }

    // Draw the swept AABB of the player to see where applied gravity is putting her
    playerAABBcolor := Vector3.{0.0, 1.0, 1.0}; // no hit
    if worldCollisionModels.count > 0 {  
        playerAABBcolor = Vector3.{1.0, 0.95, 0.0}; // hit
    } 
    // Draw3DAABB(sweptAABB_x, color = playerAABBcolor);
    // Draw3DAABB(sweptAABB_y, color = playerAABBcolor);
    // Draw3DAABB(sweptAABB_z, color = playerAABBcolor);
    
    // max := length(world.gravity);
    // dir := normalize(endBA - startBA); // we just need the direction. Any pair of the AABB will do!


    // rayVis : [1] Line;
    // noHitColor := Vector3.{1.0, 1.0, 1.0};
    // hitColor   := Vector3.{0.0, 1.0, 0.0};
    // rayVis[0] = .{
    //     a = .{pos = startBA, color = noHitColor},
    //     b = .{pos = endBA, color = noHitColor}
    // };

    // hitList : [8] HitRecord;
    // hitList[0] = Trace(startBA, endBA, max, world.models);
    // hitList[1] = Trace(startBB, endBB, max, world.models);
    // hitList[2] = Trace(startBC, endBC, max, world.models);
    // hitList[3] = Trace(startBD, endBD, max, world.models);
    // hitList[4] = Trace(startTA, endTA, max, world.models);
    // hitList[5] = Trace(startTB, endTB, max, world.models);
    // hitList[6] = Trace(startTC, endTC, max, world.models);
    // hitList[7] = Trace(startTD, endTD, max, world.models);

    // movement := world.gravity;
    // shortestDistance := max;
    // for hitList {        
    //     if it.success {
    //         //print("hit!\n");       
    //         rayVis[0] = .{
    //             a = .{pos = startBA, color = hitColor},
    //             b = .{pos = startBA + dir, color = hitColor}
    //         };
    //         if it.distance < shortestDistance {
    //             movement = it.distance*dir;
    //             shortestDistance = it.distance;
    //         }
    //     }        
    // }
    // Draw3DImmediateLines(rayVis);

    // Only apply movement when space is pressed. TODO: Remove later or map a key to pause or something.
    if keyState[SDLK_SPACE] {
        entity.pos += movement;
    }
}

Draw3DAABB :: (aabb : AABB, color := Vector3.{1.0, 0.0, 0.0}, offset := Vector3.{0.0, 0.0, 0.0}) {
    boxTris : [12] Tri;
    
    scaleExtents := aabb.maxXYZ - aabb.minXYZ;
    centerPos := aabb.minXYZ + scaleExtents/2.0;

    transform := translate(Matrix4_Identity, centerPos);
    transform = transpose(scale(transform, abs(scaleExtents)));
    for GEOM_UNIT_CUBE_CENTER {    
        // TODO: All of those vector conversions between v3 and v4 is kinda annoying!
        //       Is there a good way in jai to do this? like in glm: glm::vec4(myVec3, 1.0); ?
        a := Mat4XVec4(transform, vec3toVec4(it.a.pos));
        b := Mat4XVec4(transform, vec3toVec4(it.b.pos));
        c := Mat4XVec4(transform, vec3toVec4(it.c.pos));
        a3 := Vector3.{a.x, a.y, a.z};
        b3 := Vector3.{b.x, b.y, b.z};
        c3 := Vector3.{c.x, c.y, c.z};
        boxTris[it_index].a.pos = a3 + 0.0001*it.a.normal;
        boxTris[it_index].b.pos = b3 + 0.0001*it.b.normal;
        boxTris[it_index].c.pos = c3 + 0.0001*it.c.normal;
        boxTris[it_index].a.color = color;
        boxTris[it_index].b.color = color;
        boxTris[it_index].c.color = color;

    }
    Draw3DImmediateTris(boxTris);
}

// TODO: This kinda does not belong here. Maybe put it somewhere in the renderer code
//       and just set a flag in refdef if AABBs should be drawn or not.
AABBlines : [12] Line;
UpdateWorld :: (keyState : [] bool, mouseState : MouseState, refdef : *RefDef, world : *World) {

    UpdateOnKeys(*world.player, keyState);
    UpdateEntity(*world.player);
    ApplyGravity(keyState, world, *world.player);
    
    // TODO: Make a polymorphic function that accepts entities and the camera.
    //       This function could be called something like 'ProcessKeyboardInput' and 'ProcessMouseInput'.
    //       The passed entity (or camera) brings a control-scheme, that defines what happens to this
    //       entity on certain key- (and mouse-) presses. So in the end, UpdateCameraOnKeys and
    //       UpdateCameraOnMouse are gone. Something like that.    
    if refdef.camera.type == Camera {
        UpdateOnKeys(refdef.camera, keyState);
        if mouseState.rightButtonDown {    
            SDL_ShowCursor(0); // TODO: Should be SDL_ENABLE -> Can we fix this in SDL2 module of jai?
            UpdateCameraOnMouse(refdef.camera, mouseState.dX, mouseState.dY);
        }
        if mouseState.rightButtonWentUp {
            SDL_ShowCursor(1);
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

