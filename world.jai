
World :: struct {
    models    : [..] Model;    // World geometry: This is the old way of representing world geometry. TODO: Delete later
    tris      : [..] WorldTri; // Polysoup of all the static geometry.
    entities  : [..] BaseEntity;   // All entities: Those are moving enemies, boxes, buttons, lights, but also triggers (things that have no visual representation in the world).
    player    : BaseEntity;        // Not sure if the player should be a dedicated entity. In theory the player could be any entity!
    gravity   := Vector3.{0.0, 0.0, -10.0}; // Applied on entities every frame that are set to react to gravity.
}

FixOrientation :: (v : Vector3) -> Vector3 {
    qRight : Quaternion;
    set_from_axis_and_angle(*qRight, Vector3.{1.0, 0.0, 0.0}, -PI/2.0);
    normalize_or_identity(*qRight);
    rotation := rotation_matrix(Matrix3, qRight);
    result := rotation * v;
    return .{result.x, result.y, result.z};
}

FixBoneOrientation :: (m : Matrix4) -> Matrix4 {
    qRight : Quaternion;
    set_from_axis_and_angle(*qRight, Vector3.{1.0, 0.0, 0.0}, -PI/2.0);
    normalize_or_identity(*qRight);
    rotation := rotation_matrix(Matrix4, qRight);

    return m * rotation;
}

InitWorldGeometry :: (brushes : [] QuakeBrush, world : *World) {
    for brushes {
        tris := CreateWorldTrisFromBrush(it);
        for tris array_add(*world.tris, it);
        print("Tri-count: %\n", tris.count);
    }

    WorldTrisToGPU(world.tris);
}

InitWorldFromQuakeMap :: (map : QuakeMap, world : *World) {
    for map.entities {
        value, propertyFound := table_find(*it.properties, "classname");
        if propertyFound {
            if !compare("worldspawn", value) {
                InitWorldGeometry(it.brushes, world);
            }
        }
    }

    
}

SpawnEntities :: (entities : [] Entity, refdef : *RefDef, world : *World) {
    for entity : entities {
        modelname := GetModelNameByClassname(entity.classname);
        iqmModelPath := tprint("assets/models/%/%.iqm", modelname, modelname);
        iqmModel := LoadIQM(iqmModelPath);
        if entity.entityType == .PLAYER { // TODO: Actually load model data from disk and compute necessary stuff as AABB.
            world.player = entity;        
            array_resize(*world.player.poses, iqmModel.frameCount*iqmModel.jointCount);
            array_resize(*world.player.invBindPoses, iqmModel.invBindPoses.count);
            array_resize(*world.player.bindPoses, iqmModel.bindPoses.count);
            array_resize(*world.player.palette, iqmModel.jointCount);
            world.player.jointCount = iqmModel.jointCount;
            world.player.totalFrameCount = iqmModel.frameCount;
            for iqmModel.meshes {                
                cpuEntityModel : CPUEntityModel;
                textureID := RegisterTexture(it.material);
                cpuEntityModel.textureID = textureID;
                cpuEntityModel.start = it.firstTri;
                cpuEntityModel.triCount = it.numTris;
                i := 0;
                tris : [..] Tri;
                while i < it.vertices.count {
                    tri : Tri;
                    a := it.vertices[i + 0];
                    b := it.vertices[i + 1];
                    c := it.vertices[i + 2];
                    tri.a.pos = Vector3.{a.pos[0], a.pos[1], a.pos[2]};
                    tri.c.pos = Vector3.{b.pos[0], b.pos[1], b.pos[2]};
                    tri.b.pos = Vector3.{c.pos[0], c.pos[1], c.pos[2]};
                    // tri.a.pos = FixOrientation(tri.a.pos);
                    // tri.b.pos = FixOrientation(tri.b.pos);
                    // tri.c.pos = FixOrientation(tri.c.pos);

                    tri.a.uv = Vector2.{a.texCoord[0], a.texCoord[1]};
                    tri.c.uv = Vector2.{b.texCoord[0], b.texCoord[1]};
                    tri.b.uv = Vector2.{c.texCoord[0], c.texCoord[1]};
                    tri.a.bc = Vector3.{1.0, 0.0, 0.0};
                    tri.b.bc = Vector3.{0.0, 1.0, 0.0};
                    tri.c.bc = Vector3.{0.0, 0.0, 1.0};
                    for j : 0..3 {
                        tri.a.blendindices[j] = a.blendindices[j];
                        tri.c.blendindices[j] = b.blendindices[j];
                        tri.b.blendindices[j] = c.blendindices[j];        
                        tri.a.blendweights.component[j] = cast(float)a.blendweights[j] / 255.0;
                        tri.c.blendweights.component[j] = cast(float)b.blendweights[j] / 255.0;
                        tri.b.blendweights.component[j] = cast(float)c.blendweights[j] / 255.0;
                    }                    

                    array_add(*tris, tri);
                    array_add(*world.player.tris, tri);
                    i += 3;
                }                
                cpuEntityModel.gpuID = CreateEntityModel(tris, textureID);
                array_add(*world.player.models, cpuEntityModel);
                array_free(tris);
            }
            for iqmModel.invBindPoses {
                world.player.invBindPoses[it_index] = it;
            }
            for iqmModel.bindPoses {
                world.player.bindPoses[it_index] = it;
            }
            for iqmModel.poses {                
                world.player.poses[it_index] = it;
            }            
            for iqmModel.animations {
                array_add(*world.player.animations, it);
            }
            world.player.aabb = ComputeAABB(world.player.tris);
            world.player.currentAABB = world.player.aabb;
            world.player.pos = entity.pos;            
        }
    }
}

UpdateCameraOnMouse :: (camera : *Entity(Camera), dX : s32, dY : s32) {
    RotateAroundUp(camera, -dX * 0.01);
    RotateAroundSide(camera, -dY * 0.01);
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

// TODO: This kinda does not belong here. Maybe put it somewhere in the renderer code
//       and just set a flag in refdef if AABBs should be drawn or not.
AABBlines : [12] Line;
UpdateWorld :: (refdef : *RefDef, world : *World, frameTime : float) {

    // ApplyGravity(keyState, world, *world.player);
    // UpdateOnKeys(*world.player, frameTime);

    // gravityVector := PredictMovement(world, *world.player, world.gravity);    
    // velocity.y += world.gravity.y;
    // movementVector : Vector3;
    // velocity := world.player.predict;
    // hitGround, gravity := CheckGround(world, *world.player, frameTime);
    // if hitGround {    
    //     movementVector = PredictMovement(world, *world.player, frameTime*velocity);
    // } else {    
    //     gravity.z += velocity.z;
    //     movementVector = PredictMovement(world, *world.player, gravity);
    // }
    // world.player.pos += movementVector;
    
    // UpdateEntity(*world.player);
    
    // TODO: Make a polymorphic function that accepts entities and the camera.
    //       This function could be called something like 'ProcessKeyboardInput' and 'ProcessMouseInput'.
    //       The passed entity (or camera) brings a control-scheme, that defines what happens to this
    //       entity on certain key- (and mouse-) presses. So in the end, UpdateCameraOnKeys and
    //       UpdateCameraOnMouse are gone. Something like that.    
    // if refdef.camera.type == Camera {
    //     UpdateOnKeys(refdef.camera, frameTime);
    //     if MouseRightButtonDown() {    
    //         SDL_ShowCursor(0); // TODO: Should be SDL_ENABLE -> Can we fix this in SDL2 module of jai?
    //         UpdateCameraOnMouse(refdef.camera, GetMouseDX(), GetMouseDY());
    //     }
    //     if MouseRightButtonUp() {
    //         SDL_ShowCursor(1);
    //     }
    // } else if refdef.camera.type == FollowCamera {
    //     UpdateFollowCamera(cast(*FollowCamera)refdef.camera);        
    // }

    // Draw players AABB as wireframe. TODO: Move this into a generic function.
    // aabb := world.player.currentAABB;
    // minX := aabb.minXYZ.x;
    // minY := aabb.minXYZ.y;
    // minZ := aabb.minXYZ.z;
    // maxX := aabb.maxXYZ.x;
    // maxY := aabb.maxXYZ.y;
    // maxZ := aabb.maxXYZ.z;
    // width := aabb.width;
    // height := aabb.height;
    // depth := aabb.depth;
    // // We allocate memory here because returning an array of [12]Line lines will result in a stack overflow and crash.
    // // AABBlines := cast(*Line)alloc(12 * size_of(Line));
    // AABBlines[0] = .{
    //         a = .{pos = .{minX, minY, minZ}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{minX + width, minY, minZ}, color = .{1.0, 1.0, 1.0}} 
    // };
    // AABBlines[1] = .{
    //         a = .{pos = .{minX, minY, minZ}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{minX, minY + height, minZ}, color = .{1.0, 1.0, 1.0}} 
    // };
    // AABBlines[2] = .{
    //         a = .{pos = .{minX, minY, minZ}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{minX, minY, minZ + depth}, color = .{1.0, 1.0, 1.0}} 
    // };
    // AABBlines[3] = .{
    //         a = .{pos = .{maxX, maxY, maxZ}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{maxX - width, maxY, maxZ}, color = .{1.0, 1.0, 1.0}} 
    // };
    // AABBlines[4] = .{
    //         a = .{pos = .{maxX, maxY, maxZ}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{maxX, maxY - height, maxZ}, color = .{1.0, 1.0, 1.0}} 
    // };
    // AABBlines[5] = .{
    //         a = .{pos = .{maxX, maxY, maxZ}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{maxX, maxY, maxZ - depth}, color = .{1.0, 1.0, 1.0}} 
    // };
    // AABBlines[6] = .{
    //         a = .{pos = .{maxX, maxY, maxZ - depth}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{minX, minY + height, minZ}, color = .{1.0, 1.0, 1.0}},
    // };
    // AABBlines[7] = .{
    //         a = .{pos = .{minX, minY + height, minZ}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{maxX - width, maxY, maxZ}, color = .{1.0, 1.0, 1.0}}
    // };
    // AABBlines[8] = .{
    //         a = .{pos = .{maxX - width, maxY, maxZ}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{minX, minY, minZ + depth}, color = .{1.0, 1.0, 1.0}} 
    // };
    // AABBlines[9] = .{
    //         a = .{pos = .{minX, minY, minZ + depth}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{maxX, maxY - height, maxZ}, color = .{1.0, 1.0, 1.0}} 
    // };
    // AABBlines[10] = .{
    //         a = .{pos = .{maxX, maxY - height, maxZ}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{minX + width, minY, minZ}, color = .{1.0, 1.0, 1.0}}
    // };
    // AABBlines[11] = .{
    //         a = .{pos = .{minX + width, minY, minZ}, color = .{1.0, 1.0, 1.0}},
    //         b = .{pos = .{maxX, maxY, maxZ - depth}, color = .{1.0, 1.0, 1.0}}
    // };
    // Draw3DImmediateLines(AABBlines); // TODO: This is probably the most C way of doing this. And it is... ugly. Maybe
    // we should just *not* use immediate draw for that many lines and just create a AABB VAO, VBO. Not sure...
    // And probably this draw call should not be here at all. lol.

    // free(AABBlines);

    // Add player entity to refresh definition
    // RenderAddEntity(refdef, world.player);
}

