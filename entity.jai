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

Entity :: struct {
    #as using base := BaseEntity.{    
        VirtualUpdateOnKeys = (baseEntity : *BaseEntity, keyState : [] bool) {
            using cast(*Entity)baseEntity;
            if keyState[SDLK_h] predict.x += 1.06;
            if keyState[SDLK_f] predict.x -= 1.06;
            if keyState[SDLK_t] predict.y += 1.06;
            if keyState[SDLK_g] predict.y -= 1.06;   
            if keyState[SDLK_i] predict.z += 0.3080;  // A bit more than gravity force so we can "jump"
            if keyState[SDLK_k] predict.z -= 0.37;
            if keyState[SDLK_LEFTBRACKET] pctFrameCompletion -= 0.1;
            if keyState[SDLK_RIGHTBRACKET] pctFrameCompletion += 0.1;
            if keyState[SDLK_PERIOD] {
                currentAnim += 1;
                if currentAnim >= animations.count {
                    currentAnim = 0;
                }
            }
            if keyState[SDLK_COMMA] {
                if currentAnim == 0 {
                    if animations.count > 0 currentAnim = cast(u32)(animations.count-1);
                }
                else currentAnim -= 1;
            }
        }
    };
    classname    : string;
    entityType   : EntityType;
    pos          : Vector3;
    predict      : Vector3;
    orientation  : Quaternion;
    aabb         : AABB;    
    currentAABB  : AABB;
    tris         : [..] Tri;
    models       : [..] CPUEntityModel;
    texture      : string; // TODO: actually when processing entities in a loop, I don't really want that here!
    transform    := Matrix4_Identity; // Holds the current transformation matrix    
    followCamera : *FollowCamera = null;
    applyGravity := true; // By default the world's gravity force is applied every frame.
    poses        : [..] Pose;
    invBindPoses : [..] Matrix4;
    bindPoses    : [..] Matrix4;
    palette      : [..] Matrix4;
    jointCount   : u32;
    currentFrame : u32;
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

// TODO: THIS IS REALLY UGLY!!!
UpdateEntity :: (using entity : *Entity) { // TODO: Find out how to do namespaces (if they exist or if there is something like it)
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


    // Animation stuff


    // Set the currentFrame based on which animation we are in

    animFirstFrame := animations[currentAnim].firstFrame;
    animFrameCount := animations[currentAnim].numFrames;
    
    // Figure out the correct framepair

    pctFrameCompletion += 0.2;
    if pctFrameCompletion < 0.0 {
        if currentFrame == animFirstFrame {
            currentFrame = (animFirstFrame+animFrameCount-1);
        } else {
            currentFrame -= 1;
        }
        pctFrameCompletion = 1.0;
    }
    if pctFrameCompletion > 1.0 {
        currentFrame += 1;
        pctFrameCompletion = 0.0;        

        if currentFrame >= (animFirstFrame+animFrameCount) {
            currentFrame = animFirstFrame;
        }
    }
    nextFrame := (currentFrame + 1) % (animFirstFrame+animFrameCount);

    print("pctFrameCompletion: %, %, %\n", pctFrameCompletion, currentFrame, nextFrame);

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
    entity.predict = .{0.0, 0.0, 0.0};
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
    return "";
}

ENTITY_MODELS :: ClassnameToModel.[
    .{"info_player_start", "cylinder_two_anims"}
];