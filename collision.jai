HitRecord :: struct {
    success : bool;
    tri : Tri;
    distance : float;
}

// TODO: The PickTri proc in graphics_math.jai should use this proc as it does the same just with the cam as starting point
Trace :: (start : Vector3, end : Vector3, maxT : float, world : [] Model) -> HitRecord {
    
    r := normalize(end - start);
    shortestT := maxT;    
    bestTri : Tri;
    success := false;
    for model : world {
        for tri : model.tris {            
    
            n := tri.a.normal; // NOTE: The normal could be an average between two vertex-normals but for now we only have hard surfaces.
            c := normalize(start - tri.a.pos); 
            nDotC := dot(n, c);
            if nDotC >= 0 { // Is start pos on the positive (front side) of the plane?
                nDotR := dot(n, r);
                if nDotR < 0.0 { // Is the ray looking to the front face of the plane? Attention: Must be *really* smaller than 0 becasuse we devide by nDotR later!
                    // if nDotR >= -0.00001 && nDotR <= 0.00001 continue;
                    // compute the hitpoint p between ray and plane
                    d := -dot(n, tri.a.pos);
                    t := (-dot(n, start) - d) / nDotR;
                    p := start + t*r;
                    // print("t: %\n", t);
                    // print("r: %\n", r);
                    // print("start + t*r: %\n", p);
                    
                    v0 := normalize(tri.b.pos - tri.a.pos);
                    v1 := normalize(tri.c.pos - tri.b.pos);
                    v2 := normalize(tri.a.pos - tri.c.pos);
                    ap := normalize(p - tri.a.pos);
                    bp := normalize(p - tri.b.pos);
                    cp := normalize(p - tri.c.pos);
                    n0 := cross(v0, n);
                    n1 := cross(v1, n);
                    n2 := cross(v2, n);
                    if dot(n0, ap) > 0.0 continue;
                    if dot(n1, bp) > 0.0 continue;
                    if dot(n2, cp) > 0.0 continue;
                    if t < shortestT {
                        bestTri = tri;    
                        shortestT = t;             
                        success = true;                       
                    }
                }
            }
        }
    }

    hitPoint := start + (shortestT*r);
    
    return .{success, bestTri, shortestT};    
}

AABB :: struct {
    minXYZ := Vector3.{-1.0, -1.0, -1.0};
    maxXYZ := Vector3.{1.0, 1.0, 1.0};
    width : float = 2;
    height : float = 2;
    depth : float = 2;

    // All 8 points of the box, not sure if this is a waste of memory...
    // but makes collision detection easier. TODO: How does Quake do it?
    bottomA := Vector3.{-1.0, -1.0, -1.0}; // minXYZ, TODO: Alias in structs?
    bottomB := Vector3.{-1.0, -1.0, 1.0};
    bottomC := Vector3.{ 1.0, -1.0, 1.0};
    bottomD := Vector3. {1.0, -1.0, -1.0};

    topA := Vector3.{-1.0, 1.0, -1.0};
    topB := Vector3.{-1.0, 1.0,  1.0};
    topC := Vector3.{ 1.0, 1.0,  1.0}; // maxXYZ, TODO: Alias  in structs?
    topD := Vector3.{ 1.0, 1.0, -1.0};
}

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

    X := Vector3.{1.0, 0.0, 0.0};
    Y := Vector3.{0.0, 1.0, 0.0};
    Z := Vector3.{0.0, 0.0, 1.0};
    minXYZ := Vector3.{minX, minY, minZ};
    maxXYZ := Vector3.{maxX, maxY, maxZ};
    bottomA := minXYZ;
    bottomB := minXYZ + Z*depth;
    bottomC := bottomB + X*width;
    bottomD := bottomA + X*width;
    topA := bottomA + Y*height;
    topB := bottomB + Y*height;
    topC := bottomC + Y*height;
    topD := bottomD + Y*height;
    
    return .{
        minXYZ,
        maxXYZ,
        width, height, depth,
        bottomA, bottomB, bottomC, bottomD,
        topA, topB, topC, topD
    };
}

CheckAABB :: (a : AABB, b : AABB) -> bool {
    return !((a.maxXYZ.x  < b.minXYZ.x) || (b.maxXYZ.x < a.minXYZ.x) ||
    (a.maxXYZ.y  < b.minXYZ.y) || (b.maxXYZ.y < a.minXYZ.y) ||
    (a.maxXYZ.z  < b.minXYZ.z) || (b.maxXYZ.z < a.minXYZ.z));
}