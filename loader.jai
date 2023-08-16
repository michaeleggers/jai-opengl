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
    vertices : [..] IQMVertex;
}

IQMData :: struct {
    meshes : [..] Mesh;    
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
        for j : 0..iqmMesh.numTris-1 {
            tri := cast(*IQMTri)(pTris + firstTri*size_of(IQMTri) + j*size_of(IQMTri));
            // print("%\n", <<tri); 
            
            a := cast([3] float)(positions + tri.vertex[0] * positionStride);
            b := cast([3] float)(positions + tri.vertex[1] * positionStride);
            c := cast([3] float)(positions + tri.vertex[2] * positionStride);
            
            aUV := cast([2] float)(texCoords + tri.vertex[0] * texCoordStride);
            bUV := cast([2] float)(texCoords + tri.vertex[1] * texCoordStride);
            cUV := cast([2] float)(texCoords + tri.vertex[2] * texCoordStride);

            vertA : IQMVertex = .{pos = a, texCoord = aUV};
            vertB : IQMVertex = .{pos = b, texCoord = bUV};
            vertC : IQMVertex = .{pos = c, texCoord = cUV};

            array_add(*mesh.vertices, vertA);
            array_add(*mesh.vertices, vertB);
            array_add(*mesh.vertices, vertC);
        }
        array_add(*result.meshes, mesh);
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
