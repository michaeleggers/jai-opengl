
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

SweepAABB :: (aabb : AABB, sweep : Vector3) -> AABB, AABB, AABB {
    sweptAABB_x : AABB;
    if sweep.x > 0 {
        maxXYZ_x := aabb.maxXYZ;
        maxXYZ_x.x += sweep.x;
        sweptAABB_x.minXYZ = aabb.minXYZ;
        sweptAABB_x.maxXYZ = maxXYZ_x;
    } else {
        minXYZ_x := aabb.minXYZ;
        minXYZ_x.x += sweep.x;
        sweptAABB_x.minXYZ = minXYZ_x;
        sweptAABB_x.maxXYZ = aabb.maxXYZ;
    }

    sweptAABB_y : AABB;
    if sweep.y > 0 {
        maxXYZ_y := aabb.maxXYZ;
        maxXYZ_y.y += sweep.y;
        sweptAABB_y.minXYZ = aabb.minXYZ;
        sweptAABB_y.maxXYZ = maxXYZ_y;
    } else {
        minXYZ_y := aabb.minXYZ;
        minXYZ_y.y += sweep.y;
        sweptAABB_y.minXYZ = minXYZ_y;
        sweptAABB_y.maxXYZ = aabb.maxXYZ;
    }

    sweptAABB_z : AABB;
    if sweep.z > 0 {
        maxXYZ_z := aabb.maxXYZ;
        maxXYZ_z.z += sweep.z;
        sweptAABB_z.minXYZ = aabb.minXYZ;
        sweptAABB_z.maxXYZ = maxXYZ_z;
    } else {
        minXYZ_z := aabb.minXYZ;
        minXYZ_z.z += sweep.z;
        sweptAABB_z.minXYZ = minXYZ_z;
        sweptAABB_z.maxXYZ = aabb.maxXYZ;
    }

    return sweptAABB_x, sweptAABB_y, sweptAABB_z;
}

// grow b by a
MinkowskiAABB :: (a : AABB, b : AABB) -> AABB {
    aHalfExtents := Vector3.{
        abs(a.maxXYZ.x - a.minXYZ.x)/2.0,
        abs(a.maxXYZ.y - a.minXYZ.y)/2.0,
        abs(a.maxXYZ.z - a.minXYZ.z)/2.0
    };

    return .{
        minXYZ = b.minXYZ - aHalfExtents,
        maxXYZ = b.maxXYZ + aHalfExtents
    };    
}

CheckGround :: (world : *World, entity : *Entity) -> bool, Vector3 #must {
    // Sweep bounding box
    sweptAABB_x, sweptAABB_y, sweptAABB_z := SweepAABB(entity.currentAABB, world.gravity);

    // check AABB overlap with world geometry        
    worldCollisionModels : [..] Model;
    worldCollisionModels.allocator = temp;
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

    start : Vector3;
    start.x = entity.currentAABB.minXYZ.x + entity.aabb.width/2.0;
    start.y = entity.currentAABB.minXYZ.y + entity.aabb.height/2.0;
    start.z = entity.currentAABB.minXYZ.z + entity.aabb.depth/2.0;    
    end := start + world.gravity;
    max := length(world.gravity);
    dir := normalize(world.gravity);
    shortestDistance := max;
    hitTri : Tri;    
    doesCollide := false;
    for world.models {        
        minkowskiAABB := MinkowskiAABB(entity.currentAABB, it.aabb);
        model := CreateModelFromAABB(minkowskiAABB);
        test : [1] Model;
        test[0] = model;
        hit := Trace(start, end, max, test);        
        if hit.success { // Collision happened!
            // Draw3DImmediateTris(model.tris);            
            if hit.distance < shortestDistance {                             
                doesCollide = true;
                shortestDistance = hit.distance;                
                hitTri = hit.tri;  
                return true, .{0.0, 0.0, 0.0};
            }
        }
    }

    movement := shortestDistance*dir;
    if doesCollide {
        // It could happen that shortestDistance*dir results in a position *inside* the world geometry!
        p := start + shortestDistance*dir; // hitpoint
        aToP := normalize(p - hitTri.a.pos);
        result := dot(aToP, hitTri.a.normal);
        if result <= 0 { // <= is important because result could be -0 or 0 which is on the plane. And -0 < 0 evals to false. But we want -0 to be treated as 0!            
            offset := abs(result) + 0.001;
            p = p + 0.0001*(-dir);
            sToP := p - start;            
            movement += offset*(hitTri.a.normal); // move away along the normal so we are outside the level geometry
        }
    }

    return false, movement;
}

// TODO: Do I need a physics.jai?
// TODO: This stuff is probably very expensive!!!
PredictMovement :: (world : *World, entity : *Entity, velocity : Vector3) -> Vector3 {

    // Sweep bounding box
    sweptAABB_x, sweptAABB_y, sweptAABB_z := SweepAABB(entity.currentAABB, velocity);

    // check AABB overlap with world geometry        
    worldCollisionModels : [..] Model;
    worldCollisionModels.allocator = temp;
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

    start : Vector3;
    start.x = entity.currentAABB.minXYZ.x + entity.aabb.width/2.0;
    start.y = entity.currentAABB.minXYZ.y + entity.aabb.height/2.0;
    start.z = entity.currentAABB.minXYZ.z + entity.aabb.depth/2.0;    
    end := start + velocity;
    max := length(velocity);
    dir := normalize(velocity);
    shortestDistance := max;
    hitTri : Tri;    
    doesCollide := false;
    for world.models {        
        minkowskiAABB := MinkowskiAABB(entity.currentAABB, it.aabb);
        model := CreateModelFromAABB(minkowskiAABB);
        test : [1] Model;
        test[0] = model;
        hit := Trace(start, end, max, test);        
        if hit.success { // Collision happened!
            // Draw3DImmediateTris(model.tris);            
            if hit.distance < shortestDistance {                             
                doesCollide = true;
                shortestDistance = hit.distance;                
                hitTri = hit.tri;                              
            }
        }
    }

    movement := shortestDistance*dir;
    if doesCollide {
        // It could happen that shortestDistance*dir results in a position *inside* the world geometry!
        p := start + shortestDistance*dir; // hitpoint
        aToP := normalize(p - hitTri.a.pos);
        result := dot(aToP, hitTri.a.normal);
        if result <= 0 { // <= is important because result could be -0 or 0 which is on the plane. And -0 < 0 evals to false. But we want -0 to be treated as 0!            
            offset := abs(result) + 0.001;
            p = p + 0.0001*(-dir);
            sToP := p - start;            
            movement += offset*(hitTri.a.normal); // move away along the normal so we are outside the level geometry
        }
    }
    
    if shortestDistance < 0.000001 {
        slideFactor := dot(-dir, hitTri.a.normal);
        // print("slideFactor: %\n", slideFactor);
        slide := hitTri.a.normal + dir; // Vector from inversed dir towards tip of tris normal
        // movement += slide;
    }

    // Visualize movement
    rayVis : [1] Line;
    rayVis[0] = .{
        a = .{pos = entity.currentAABB.minXYZ, color = .{1.0, 1.0, 1.0}},
        b = .{pos = entity.currentAABB.minXYZ + movement, color = .{1.0, 1.0, 1.0}}
    };
    Draw3DImmediateLines(rayVis);


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
    
 
    // Only apply movement when space is pressed. TODO: Remove later or map a key to pause or something.
    // if keyState[SDLK_SPACE] {        
    //     entity.pos += movement;
    // }
    // entity.pos += movement;

    return movement;
}

CreateModelFromAABB :: (aabb : AABB, color := Vector3.{0.5, 0.5, 0.5}) -> Model {
    result : Model;
    result.tris.allocator = temp;

    // TODO: The following is the same as in Draw3DAABB!
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
        boxTris[it_index].a.pos = a3;
        boxTris[it_index].b.pos = b3;
        boxTris[it_index].c.pos = c3;
        boxTris[it_index].a.normal = it.a.normal;
        boxTris[it_index].b.normal = it.b.normal;
        boxTris[it_index].c.normal = it.c.normal;
        boxTris[it_index].a.color = color;
        boxTris[it_index].b.color = color;
        boxTris[it_index].c.color = color;
    }

    result.aabb = aabb;
    for boxTris {
        array_add(*result.tris, it);        
    }    

    return result;
}

Draw3DAABB :: (aabb : AABB, color := Vector3.{1.0, 0.0, 0.0}) {
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

    // ApplyGravity(keyState, world, *world.player);
    UpdateOnKeys(*world.player, keyState);

    // gravityVector := PredictMovement(world, *world.player, world.gravity);    
    // velocity.y += world.gravity.y;
    hitGround, gravity := CheckGround(world, *world.player);
    if hitGround {
        print("Hit ground. Don't apply gravity...\n");
    } else {
        print("Didn't hit ground. Apply gravity...\n");
        world.player.pos += gravity;
    }
    velocity := world.player.predict;
    movementVector := PredictMovement(world, *world.player, velocity);
    world.player.pos += (movementVector);
    
    UpdateEntity(*world.player);
    
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

