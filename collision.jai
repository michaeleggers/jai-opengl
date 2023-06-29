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
