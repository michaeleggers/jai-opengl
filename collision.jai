HitRecord :: struct {
    success : bool;
    tri : Tri;
    distance : float;
}

// TODO: The PickTri proc in graphics_math.jai should use this proc as it does the same just with the cam as starting point
Trace :: (start : Vector3, end : Vector3, maxT : float, models : [] Model) -> HitRecord {
    
    r := normalize(end - start);
    shortestT := maxT;    
    bestTri : Tri;
    success := false;
    for model : models {
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

// TODO: All this stuff below should be replaced by some solid collision detection stuff.

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

CheckGround :: (world : *World, entity : *Entity, frameTime : float) -> bool, Vector3 #must {
    // Sweep bounding box
    sweptAABB_x, sweptAABB_y, sweptAABB_z := SweepAABB(entity.currentAABB, frameTime*world.gravity);

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
    end := start + frameTime*world.gravity;
    max := length(frameTime*world.gravity);
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

