ClassnameToModel :: struct {
    classname : string;
    modelname : string;
}

EntityType :: enum u32 {
    PLAYER;
}

CPUEntityModel :: struct {
    gpuID       : u32; // ID into entity model array in render.jai
    textureID   : u32;
    // Start and end indices into Entity::tris
    // TODO: Use those to index into the VBO. Currently we create a new VBO for each mesh. Yeah, and maybe we should call it mesh and not model.
    //       We could also batch data, because many entities may share the same material, just like static geometry.
    start       : u32;
    triCount    : u32;
};

BigEntity :: struct {
    // #as using base := BaseEntity.{    
    //     VirtualUpdateOnKeys = (baseEntity : *BaseEntity, frameTime : float) {
    //         using cast(*Entity)baseEntity;
    //         if KeyPressed(KeyboardButton.H)               predict.x += 0.6;
    //         if KeyPressed(KeyboardButton.F)               predict.x -= 0.6;
    //         if KeyPressed(KeyboardButton.T)               predict.y += 0.6;
    //         if KeyPressed(KeyboardButton.G)               predict.y -= 0.6;   
    //         if KeyPressed(KeyboardButton.I)               predict.z += 0.1;  // A bit more than gravity force so we can "jump"
    //         if KeyPressed(KeyboardButton.K)               predict.z -= 0.1;
    //         if KeyPressed(KeyboardButton.LEFTBRACKET)     pctFrameCompletion -= 0.1;
    //         if KeyPressed(KeyboardButton.RIGHTBRACKET)    pctFrameCompletion += 0.1;
    //     }
    // };

    classname    : string; // TODO: Should be in BaseEntity?
    entityType   : EntityType; // TODO: Not needed after refactor, I guess...
    predict      : Vector3;
    orientation  : Quaternion;
    aabb         : AABB;    
    currentAABB  : AABB;
    tris         : [..] Tri;
    models       : [..] CPUEntityModel;
    texture      : string; // TODO: actually when processing entities in a loop, I don't really want that here!
    transform    := Matrix4_Identity; // Holds the current transformation matrix    
    // followCamera : *FollowCamera = null;
    applyGravity := true; // By default the world's gravity force is applied every frame.
    poses        : [..] Pose;
    invBindPoses : [..] Matrix4;
    bindPoses    : [..] Matrix4;
    palette      : [..] Matrix4;
    jointCount   : u32;
    currentFrame : u32;
    currentFrameFPS : float;
    totalFrameCount   : u32;
    pctFrameCompletion : float;
    animations   : [..] Anim;
    currentAnim  : u32;
}

Pose :: struct {
    parent      : s32;
    translation : Vector3;
    scale       : Vector3;
    rotation    : Quaternion;
}

Anim :: struct {
    name : string;
    firstFrame, numFrames : u32;
    framerate : float;
}

CreateBigEntity :: (iqmModelPath : string, position : Vector3) -> Entity(BigEntity) {
    bigEntity : Entity(BigEntity);
    bigEntity.instance = BigEntity.{};
    iqmModel := LoadIQM(iqmModelPath);        
    array_resize(*bigEntity.instance.poses, iqmModel.frameCount*iqmModel.jointCount);
    array_resize(*bigEntity.instance.invBindPoses, iqmModel.invBindPoses.count);
    array_resize(*bigEntity.instance.bindPoses, iqmModel.bindPoses.count);
    array_resize(*bigEntity.instance.palette, iqmModel.jointCount);
    bigEntity.instance.jointCount = iqmModel.jointCount;
    bigEntity.instance.totalFrameCount = iqmModel.frameCount;
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
            tri.b.pos = Vector3.{b.pos[0], b.pos[1], b.pos[2]};
            tri.c.pos = Vector3.{c.pos[0], c.pos[1], c.pos[2]};
            // tri.a.pos = FixOrientation(tri.a.pos);
            // tri.b.pos = FixOrientation(tri.b.pos);
            // tri.c.pos = FixOrientation(tri.c.pos);

            tri.a.uv = Vector2.{a.texCoord[0], a.texCoord[1]};
            tri.b.uv = Vector2.{b.texCoord[0], b.texCoord[1]};
            tri.c.uv = Vector2.{c.texCoord[0], c.texCoord[1]};
            tri.a.bc = Vector3.{1.0, 0.0, 0.0};
            tri.b.bc = Vector3.{0.0, 1.0, 0.0};
            tri.c.bc = Vector3.{0.0, 0.0, 1.0};
            for j : 0..3 {
                tri.a.blendindices[j] = a.blendindices[j];
                tri.b.blendindices[j] = b.blendindices[j];
                tri.c.blendindices[j] = c.blendindices[j];        
                tri.a.blendweights.component[j] = cast(float)a.blendweights[j] / 255.0;
                tri.b.blendweights.component[j] = cast(float)b.blendweights[j] / 255.0;
                tri.c.blendweights.component[j] = cast(float)c.blendweights[j] / 255.0;
            }                    

            array_add(*tris, tri);
            array_add(*bigEntity.instance.tris, tri);
            i += 3;
        }                
        cpuEntityModel.gpuID = CreateEntityModel(tris, textureID);
        array_add(*bigEntity.instance.models, cpuEntityModel);
        array_free(tris);
    }
    for iqmModel.invBindPoses {
        bigEntity.instance.invBindPoses[it_index] = it;
    }
    for iqmModel.bindPoses {
        bigEntity.instance.bindPoses[it_index] = it;
    }
    for iqmModel.poses {                
        bigEntity.instance.poses[it_index] = it;
    }            
    for iqmModel.animations {
        array_add(*bigEntity.instance.animations, it);
    }
    bigEntity.instance.aabb = ComputeAABB(bigEntity.instance.tris);
    bigEntity.instance.currentAABB = bigEntity.instance.aabb;
    bigEntity.position = position;            

    return bigEntity;
}

// TODO: THIS IS REALLY UGLY!!!
UpdateBigEntity :: (bigEntity : *Entity(BigEntity)) { // TODO: Find out how to do namespaces (if they exist or if there is something like it)

    //entity := cast(*Entity(BigEntity))baseEntity;
    using bigEntity.instance;

    // update transform matrix
    transform = transpose(make_translation_matrix4(bigEntity.position));

    // apply that transform to AABB. We need it on CPU side for collision detection
    minXYZ := Mat4XVec4(transform, vec3toVec4(aabb.minXYZ));
    maxXYZ := Mat4XVec4(transform, vec3toVec4(aabb.maxXYZ));

    // NOTE: The extents *could* change. Account for that in the future...
    width := aabb.width;
    height := aabb.height;
    depth := aabb.depth;

    X := Vector3.{1.0, 0.0, 0.0};
    Y := Vector3.{0.0, 1.0, 0.0};
    Z := Vector3.{0.0, 0.0, 1.0};
    minXYZ3 := Vector3.{minXYZ.x, minXYZ.y, minXYZ.z};
    maxXYZ3 := Vector3.{maxXYZ.x, maxXYZ.y, maxXYZ.z};
    currentAABB.minXYZ = minXYZ3;
    currentAABB.maxXYZ = maxXYZ3; 
    currentAABB.bottomA = minXYZ3;
    currentAABB.bottomB = minXYZ3 + Z*depth;
    currentAABB.bottomC = currentAABB.bottomB + X*width;
    currentAABB.bottomD = currentAABB.bottomA + X*width;
    currentAABB.topA = currentAABB.bottomA + Y*height;
    currentAABB.topB = currentAABB.bottomB + Y*height;
    currentAABB.topC = currentAABB.bottomC + Y*height;
    currentAABB.topD = currentAABB.bottomD + Y*height;


    // Animation stuff


    // Set the currentFrame based on which animation we are in

    fps := animations[currentAnim].framerate;    
    timePerFrame := 1.0 / fps;
    pctFrameCompletion += (getFrameTime()/timePerFrame);

    setNewAnim := false;
    if KeyDown(KeyboardButton.COMMA) {
        print("comma released\n");
        currentAnim += 1;
        if currentAnim >= animations.count {
            currentAnim = 0;
        }
        setNewAnim = true;
    }
    if KeyDown(KeyboardButton.PERIOD) {
        if currentAnim == 0 {
            if animations.count > 0 currentAnim = cast(u32)(animations.count-1);
        }
        else currentAnim -= 1;
        setNewAnim = true;
    }

    animFirstFrame := animations[currentAnim].firstFrame;
    animFrameCount := animations[currentAnim].numFrames;
    if setNewAnim {
        pctFrameCompletion = 0.0;
        currentFrame = animFirstFrame;
    }

    // Figure out the correct framepair

    if pctFrameCompletion < 0.0 {
        if currentFrame == animFirstFrame {
            currentFrame = (animFirstFrame+animFrameCount-1);
        } else {
            currentFrame -= cast(u32)pctFrameCompletion;
        }
        pctFrameCompletion = 1.0;
    }
    if pctFrameCompletion > 1.0 {
        currentFrame += cast(u32)pctFrameCompletion;
        pctFrameCompletion = 0.0;

        if currentFrame >= (animFirstFrame+animFrameCount) {
            currentFrame = animFirstFrame;
        }
    }
    nextFrame := (currentFrame + 1) % (animFirstFrame+animFrameCount);

    // print("pctFrameCompletion: %, %, %\n", pctFrameCompletion, currentFrame, nextFrame);

    // Interpolate pose matrices
    currentPoses : [..] Matrix4;
    array_resize(*currentPoses, jointCount);
    offset := currentFrame*jointCount;
    nextPoseOffset := nextFrame*jointCount;
    for i : 0..jointCount-1 {
        pose := poses[i + offset];
        nextPose := poses[i + nextPoseOffset];
        poseMatrix := InterpolatePose(pose, nextPose, pctFrameCompletion);
        if pose.parent >= 0 {
            currentPoses[i] = currentPoses[pose.parent] * poseMatrix;
        } else {
            currentPoses[i] = poseMatrix;
        }
    }        

    // Rebuild matrix palette
    for i : 0..jointCount-1 {
        palette[i] = transpose(currentPoses[i] * invBindPoses[i]); // transpose, because OpenGL is column-major
    }
    array_free(currentPoses);

    // Reset wish movement vector  
    predict = .{0.0, 0.0, 0.0};
}

InterpolatePose :: (pose : Pose, nextPose : Pose, pctFrameCompletion: float) -> Matrix4 {
    translation := (1.0 - pctFrameCompletion)*pose.translation + pctFrameCompletion*nextPose.translation;
    scale := (1.0 - pctFrameCompletion)*pose.scale + pctFrameCompletion*nextPose.scale;
    // Test for shortest path between the two quaternions
    r1 := pose.rotation;
    r2 := nextPose.rotation;
    r1DotR2 := dot(r1, r2);
    if r1DotR2 < 0 r2 = -r2;
    // Only then do the interpolation
    rotation := slerp(r1, r2, pctFrameCompletion);
    // normalize_or_identity(*rotation);
    return make_translation_matrix4(translation) * rotation_matrix(Matrix4, rotation) * make_scale_matrix4(scale);
}

GetModelNameByClassname :: (classname : string) -> string {
    for ENTITY_MODELS {
        if !compare(classname, it.classname) {
            return it.modelname;
        }
    }
    assert(false, "No model found for classname: %\n", classname);
    return ""; // Cannot happen
}

ENTITY_MODELS :: ClassnameToModel.[
    .{"info_player_start", "cylinder_two_anims"}
];