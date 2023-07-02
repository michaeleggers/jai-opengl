
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

// TODO: Do I need a physics.jai?
// TODO: This stuff is probably very expensive!!!
ApplyGravity :: (world : *World, entity : *Entity) {
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
    
    // check AABB overlap with world geometry    
    for world.models {    
        if CheckAABB(world.player.currentAABB, it.aabb) {
            print("intersection with world model which is at: %\n", it.position); break;
        } else {
            print("No intersection.\n");
        }
    }

    max := length(world.gravity);
    dir := normalize(endBA - startBA); // we just need the direction. Any pair of the AABB will do!

    rayVis : [1] Line;
    noHitColor := Vector3.{1.0, 1.0, 1.0};
    hitColor   := Vector3.{0.0, 1.0, 0.0};
    rayVis[0] = .{
        a = .{pos = startBA, color = noHitColor},
        b = .{pos = endBA, color = noHitColor}
    };

    hitList : [8] HitRecord;
    hitList[0] = Trace(startBA, endBA, max, world.models);
    hitList[1] = Trace(startBB, endBB, max, world.models);
    hitList[2] = Trace(startBC, endBC, max, world.models);
    hitList[3] = Trace(startBD, endBD, max, world.models);
    hitList[4] = Trace(startTA, endTA, max, world.models);
    hitList[5] = Trace(startTB, endTB, max, world.models);
    hitList[6] = Trace(startTC, endTC, max, world.models);
    hitList[7] = Trace(startTD, endTD, max, world.models);

    movement := world.gravity;
    shortestDistance := max;
    for hitList {        
        if it.success {
            //print("hit!\n");       
            rayVis[0] = .{
                a = .{pos = startBA, color = hitColor},
                b = .{pos = startBA + dir, color = hitColor}
            };
            if it.distance < shortestDistance {
                movement = it.distance*dir;
                shortestDistance = it.distance;
            }
        }        
    }
    Draw3DImmediateLines(rayVis);

    entity.pos += movement;
}

// TODO: This kinda does not belong here. Maybe put it somewhere in the renderer code
//       and just set a flag in refdef if AABBs should be drawn or not.
AABBlines : [12] Line;
UpdateWorld :: (keyState : [] bool, mouseState : MouseState, refdef : *RefDef, world : *World) {

    UpdateOnKeys(*world.player, keyState);
    UpdateEntity(*world.player);
    ApplyGravity(world, *world.player);
    
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

