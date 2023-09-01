// TODO: Just setup pointers so that API functions later can directly peek into the loaded data.
//       Currently this code loads everything into arrays and then later we copy data into
//       another array in the client code. This is pretty dumb... For now, it is okay. Still exploring.

#import "Basic";
#import "File";

IQMHeader :: struct {
    magic : [16]u8; // "INTERQUAKEMODEL\0"
    version : u32; // Must be version 2
    filesize : u32;
    flags : u32;
    numText, ofsText : u32;
    numMeshes, ofsMeshes : u32;
    numVertArrays, numVertices, ofsVertArrays : u32;
    numTris, ofsTris, ofsAdjacency : u32;
    numJoints, ofsJoints : u32;
    numPoses, ofsPoses : u32;
    numAnims, ofsAnims : u32;
    numFrames, numFrameChannels, ofsFrames, ofsBounds : u32;
    numComment, ofsComment : u32;
    numExt, ofsExt : u32;
}

IQMMesh :: struct {
    name : u32;
    material : u32;
    firstVert, numVerts : u32;
    firstTri, numTris : u32;
}

Mesh :: struct {
    material : string;
    vertices : [..] IQMVertex;
    firstTri, numTris : u32;
}

IQMData :: struct {
    meshes       : [..] Mesh;    
    bindPoses    : [] Matrix4;
    invBindPoses : [] Matrix4;
    poses        : [] Pose;
    jointCount   : u32;
    frameCount   : u32;  
}

IQMVertArray :: struct {
    type : u32;
    flags : u32;
    format  : u32;
    size : u32;
    offset : u32;
}

// Default Vertex format
IQMVertex :: struct {
    pos : [3] float;
    texCoord : [2] float;
    normal : [3] float;
    tangent : [4] float;
    blendindices : [4] u8;
    blendweights : [4] u8;
    color : [4] u8;
}

IQMVertArrayType :: enum u32 {
    POSITION;
    TEXCOORD;
    NORMAL;
    TANGENT;
    BLENDINDEXES;
    BLENDWEIGHTS;
    COLOR;

    CUSTOM :: 0x10;
}

IQMVertArrayFormat :: enum u32  {
    BTYE;
    UBYTE;
    SHORT;
    USHORT;
    INT;
    UINT;
    HALF;
    FLOAT;
    DOUBLE;
}

IQMTri :: struct {
    vertex : [3] u32;
}

IQMJoint :: struct {
    name : u32;
    parent : s32;
    translate : [3] float;
    rotate : [4] float;
    scale : [3] float;
}

IQMPose :: struct {
    parent : s32;
    channelmask : u32;
    channeloffset : [10] float;
    channelscale : [10] float;
}

IQMAnim :: struct {
    name : u32;
    firstFrame, numFrames : u32;
    framerate : float;
    flags : u32;
}

// Return length of a c-string including null-byte.
strlen :: (c : *u8) -> s64 {    
    count : s64 = 0;
    while <<c {
        c += 1; count += 1;
    }
    
    return count + 1;
}

LoadIQM :: (file : string) -> IQMData {
    iqmFile, success := read_entire_file(file);
    if (!success) {
        print("Failed to open file: %\n", file);
        return .{};
    }

    pHeader := cast(*IQMHeader)iqmFile.data;
    pText := iqmFile.data + pHeader.ofsText;
    pMeshes :=  iqmFile.data + pHeader.ofsMeshes;
    pVertArrays := iqmFile.data + pHeader.ofsVertArrays;
    pTris := iqmFile.data + pHeader.ofsTris;
    pAdjacency := iqmFile.data + pHeader.ofsAdjacency;
    pJoints := iqmFile.data + pHeader.ofsJoints;
    pPoses := iqmFile.data + pHeader.ofsPoses;
    pAnims := iqmFile.data + pHeader.ofsAnims;
    pFrames := iqmFile.data + pHeader.ofsFrames;
    pBounds := iqmFile.data + pHeader.ofsBounds;
    pComment := iqmFile.data + pHeader.ofsComment;
    pExts := iqmFile.data + pHeader.ofsExt;

    print("pHeader:\n%\n", <<pHeader);
    print("pHeader magic: %\n", to_string(pHeader.magic));
    print("pHeader numText: %\n", pHeader.numText);
    nextTextOfs : s64 = 0;

    while nextTextOfs < pHeader.numText-1 {
        c := pText + nextTextOfs;
        len := strlen(c);
        print("%, len: %\n", to_string(c), len);
        nextTextOfs += len;
    }
    print("nextTextOfs: %\n", nextTextOfs);

    
    print("Meshes:\n");
    for i : 0..pHeader.numMeshes-1 {    
        mesh := cast(*IQMMesh)(pMeshes + i*size_of(IQMMesh));
        name := pText + mesh.name;     
        material := pText + mesh.material;
        print("name: %\n", to_string(name));
        print("material : %\n\n", to_string(material));
        
        pVertices := iqmFile.data +  mesh.firstVert;
    }

    print("Vertex Arrays:\n");
    positions := null;
    positionStride := 0;
    texCoords := null;
    texCoordStride := 0;
    blendIndices := null;
    blendIndexStride := 0;
    blendWeights := null;
    blendWeightStride := 0;
    for i : 0..pHeader.numVertArrays-1 {
        vertArray := cast(*IQMVertArray)(pVertArrays + i*size_of(IQMVertArray));
        type : IQMVertArrayType = cast(IQMVertArrayType)vertArray.type;
        format : IQMVertArrayFormat = cast(IQMVertArrayFormat)vertArray.format;
        numComponents := vertArray.size;
        offset := vertArray.offset;
        if type == .POSITION {
            print("type is POSITION!\n");
            positions = iqmFile.data + offset;
            dataSize := 0;
            if format == .FLOAT {
                dataSize = size_of(float);
            }
            positionStride = numComponents * dataSize;
        } else if type == .TEXCOORD {
            texCoords = iqmFile.data + offset;
            dataSize := 0;
            if format == .FLOAT {
                print("UV format is FLOAT\n");
                dataSize = size_of(float);
            }
            texCoordStride = numComponents * dataSize;
        } else if type == .BLENDINDEXES {
            blendIndices = iqmFile.data + offset;
            dataSize := 0;
            if format == .UBYTE {
                dataSize = size_of(u8);
            }
            blendIndexStride = numComponents * dataSize;            
        } else if type == .BLENDWEIGHTS {
            blendWeights = iqmFile.data + offset;
            dataSize := 0;
            if format == .UBYTE {
                dataSize = size_of(u8);
            }
            blendWeightStride = numComponents * dataSize;
        }

        print("type: %, format: %, numComponents: %, offset: %\n", type, format, numComponents, offset);
        print("%\n", <<vertArray);       
        print("positionStride: %\n", positionStride);
    }

    result : IQMData;

    for i : 0..pHeader.numMeshes-1 {    
        iqmMesh := cast(*IQMMesh)(pMeshes + i*size_of(IQMMesh));
        firstTri := iqmMesh.firstTri;     
        print("first tri: %\n", firstTri);   
        print("num tris: %\n", iqmMesh.numTris);
        mesh : Mesh;
        mesh.material = to_string(pText + iqmMesh.material);
        mesh.firstTri = iqmMesh.firstTri;
        mesh.numTris = iqmMesh.numTris;
        for j : 0..iqmMesh.numTris-1 {
            tri := cast(*IQMTri)(pTris + firstTri*size_of(IQMTri) + j*size_of(IQMTri));
            // print("%\n", <<tri); 
            
            a := cast([3] float)(positions + tri.vertex[0] * positionStride);
            b := cast([3] float)(positions + tri.vertex[1] * positionStride);
            c := cast([3] float)(positions + tri.vertex[2] * positionStride);
            
            aUV := cast([2] float)(texCoords + tri.vertex[0] * texCoordStride); aUV[1] = 1 - aUV[1];
            bUV := cast([2] float)(texCoords + tri.vertex[1] * texCoordStride); bUV[1] = 1 - bUV[1];
            cUV := cast([2] float)(texCoords + tri.vertex[2] * texCoordStride); cUV[1] = 1 - cUV[1];

            aBlendIdx := cast([4] u8)(blendIndices + tri.vertex[0] * blendIndexStride);
            bBlendIdx := cast([4] u8)(blendIndices + tri.vertex[1] * blendIndexStride);
            cBlendIdx := cast([4] u8)(blendIndices + tri.vertex[2] * blendIndexStride);

            aWeights := cast([4] u8)(blendWeights + tri.vertex[0] * blendWeightStride);
            bWeights := cast([4] u8)(blendWeights + tri.vertex[1] * blendWeightStride);
            cWeights := cast([4] u8)(blendWeights + tri.vertex[2] * blendWeightStride);

            vertA : IQMVertex = .{pos = a, texCoord = aUV, blendindices = aBlendIdx, blendweights = aWeights};
            vertB : IQMVertex = .{pos = b, texCoord = bUV, blendindices = bBlendIdx, blendweights = bWeights};
            vertC : IQMVertex = .{pos = c, texCoord = cUV, blendindices = cBlendIdx, blendweights = cWeights};

            array_add(*mesh.vertices, vertA);
            array_add(*mesh.vertices, vertB);
            array_add(*mesh.vertices, vertC);
        }
        array_add(*result.meshes, mesh);
    }

    globalBindPoses : [..] Matrix4;
    bindPoses : [..] Matrix4;
    array_resize(*bindPoses, pHeader.numJoints);
    invBindPoses : [..] Matrix4;
    array_resize(*invBindPoses, pHeader.numJoints);
    print("Joints, #%:\n", pHeader.numJoints);
    for i : 0..pHeader.numJoints-1 {
        iqmJoint := cast(*IQMJoint)(pJoints + i*size_of(IQMJoint));
        name := to_string(pText + iqmJoint.name);
        print("%, ", name);
        // print("translation: %\n", iqmJoint.translate);
        translation := Vector3.{ iqmJoint.translate[0], iqmJoint.translate[1], iqmJoint.translate[2] };
        rotation := Quaternion.{ iqmJoint.rotate[0], iqmJoint.rotate[1], iqmJoint.rotate[2], iqmJoint.rotate[3] };
        scalee := Vector3.{iqmJoint.scale[0], iqmJoint.scale[1], iqmJoint.scale[2]};
        // scale: Not really interested.
        // m := Matrix4_Identity;
        // normalize_or_identity(*rotation);
        
        // // set_rotation(*m, rotation);
        // m = rotation_matrix(Matrix4, rotation);
        // scale(*m, scalee);
        // m = translate(m, translation);
        m := make_translation_matrix4(translation)
        * rotation_matrix(Matrix4, rotation)
        * make_scale_matrix4 (scalee);
        bindPoses[i] = m;
        invBindPoses[i] = m;
        if iqmJoint.parent >= 0 {
            bindPoses[i] = bindPoses[iqmJoint.parent] * bindPoses[i];
            invBindPoses[i] = invBindPoses[iqmJoint.parent] * invBindPoses[i];
        }
        // array_add(*globalBindPoses, invBindPoses[i] * bindPoses[i]);
    }
    // Step 2: Invert globale bind poses
    for i : 0..invBindPoses.count-1 {
        invBindPoses[i] = inverse(invBindPoses[i]); // TODO: Should be called globalInvBindPoses
    }

    result.bindPoses = array_copy(bindPoses);
    result.invBindPoses = array_copy(invBindPoses);
    
    poses : [..] Pose;
    framedata := cast(*u16)(pFrames);
    for i : 0..pHeader.numFrames-1 {
        for j : 0..pHeader.numPoses-1 {
            iqmPose := cast(*IQMPose)(pPoses + j*size_of(IQMPose));
            translation, scalee : Vector3;
            rotation : Quaternion;
            translation.x = iqmPose.channeloffset[0]; if iqmPose.channelmask & 0x01 { translation.x += cast(float)<<framedata * iqmPose.channelscale[0]; framedata += 1; }
            translation.y = iqmPose.channeloffset[1]; if iqmPose.channelmask & 0x02 { translation.y += cast(float)<<framedata * iqmPose.channelscale[1]; framedata += 1; }
            translation.z = iqmPose.channeloffset[2]; if iqmPose.channelmask & 0x04 { translation.z += cast(float)<<framedata * iqmPose.channelscale[2]; framedata += 1; }
            rotation.x = iqmPose.channeloffset[3];    if iqmPose.channelmask & 0x08 { rotation.x += (cast(float)<<framedata * iqmPose.channelscale[3]);    framedata += 1; }     
            rotation.y = iqmPose.channeloffset[4];    if iqmPose.channelmask & 0x10 { rotation.y += (cast(float)<<framedata * iqmPose.channelscale[4]);    framedata += 1; }
            rotation.z = iqmPose.channeloffset[5];    if iqmPose.channelmask & 0x20 { rotation.z += (cast(float)<<framedata * iqmPose.channelscale[5]);    framedata += 1; }
            rotation.w = iqmPose.channeloffset[6];    if iqmPose.channelmask & 0x40 { rotation.w += (cast(float)<<framedata * iqmPose.channelscale[6]);    framedata += 1; }
            scalee.x = iqmPose.channeloffset[7];     if iqmPose.channelmask & 0x80 { scalee.x += cast(float)<<framedata * iqmPose.channelscale[7];     framedata += 1; }
            scalee.y = iqmPose.channeloffset[8];     if iqmPose.channelmask & 0x100 { scalee.y += cast(float)<<framedata * iqmPose.channelscale[8];    framedata += 1; }
            scalee.z = iqmPose.channeloffset[9];     if iqmPose.channelmask & 0x200 { scalee.z += cast(float)<<framedata * iqmPose.channelscale[9];    framedata += 1; }

            // normalize_or_identity(*rotation);
            // m := make_translation_matrix4(translation)
            // * make_scale_matrix4 (scalee)
            // * rotation_matrix(Matrix4, rotation);
            pose : Pose;
            pose.parent = iqmPose.parent;
            pose.translation = translation;
            pose.scale = scalee;
            pose.rotation = rotation;

            // if iqmPose.parent >= 0 {
            //     poseMatrix = bindPoses[iqmPose.parent] * m * invBindPoses[j];
            // } else {
            //     poseMatrix = m * invBindPoses[j];
            // }
            // array_add(*poseMatrices, poseMatrix);
            array_add(*poses, pose);
        }
        // break; // DELETE LATER! JUST DEBUG STUFF!
    }

    result.poses = array_copy(poses);
    // result.poseMatrices = array_copy(globalBindPoses);
    result.jointCount = pHeader.numJoints;
    result.frameCount = pHeader.numFrames;

    print("Animations, #%\n", pHeader.numAnims);
    for i : 0..pHeader.numAnims-1 {
        iqmAnim := cast(*IQMAnim)(pAnims + i*size_of(IQMAnim));
        name := to_string(pAnims + iqmAnim.name);
        print("name: %\n", name);
        print("%\n", <<iqmAnim);
    }

    // exit(1);

    return result;
}

// main :: () {

//     iqm := LoadIQM("assets/mrfixit.iqm");
//     for iqm.vertices {
//         print("%\n", it);
//     }
// }
