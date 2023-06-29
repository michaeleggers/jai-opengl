#import "Basic";
#import "Math";

LookAt :: (pos : Vector3, center : Vector3, up : Vector3) -> Matrix4 {
    result := Matrix4_Identity;
    
    forward := normalize(center - pos);
    side := normalize(cross(forward, up));
    newUp := cross(side, forward);

    result._11 = side.x;
    result._21 = side.y;
    result._31 = side.z;
    result._12 = newUp.x;
    result._22 = newUp.y;
    result._32 = newUp.z;
    result._13 = -forward.x;
    result._23 = -forward.y;
    result._33 = -forward.z;
    result._41 = -dot(side, pos);
    result._42 = -dot(newUp, pos);
    result._43 =  dot(forward, pos);

    return result;
}

// Expect fov to be in radians
Perspective :: (fov : float, aspect : float, near : float, far : float) -> Matrix4 {
    result : Matrix4;

    d := tan(fov / 2.0);
    range := far - near;
    
    result._11 = 1.0 / (d * aspect);
    result._22 = 1.0 / d;
    result._33 = - (far + near) / range;
    result._34 = - 1.0;
    result._43 = - (2.0*far*near) / range;
    result._44 = 0.0;

    return result;
}

// From Lengyel, FOGED, Vol. 1, page 50
Inverse :: (m : Matrix4) -> Matrix4 {
    a := Vector3.{m._11, m._12, m._13};
    b := Vector3.{m._21, m._22, m._23};
    c := Vector3.{m._31, m._32, m._33};
    d := Vector3.{m._41, m._42, m._43};

    x := m._14;
    y := m._24;
    z := m._34;
    w := m._44;

    s := cross(a, b);
    t := cross(c, d);
    u := a*y - b*x;
    v := c*w - d*z;

    invDet := 1.0 / (dot(s, v) + dot(t, u));
    s *= invDet;
    t *= invDet;
    u *= invDet;
    v *= invDet;

    r0 := cross(b, v) + t*y;
    r1 := cross(v, a) - t*x;
    r2 := cross(d, u) + s*w;
    r3 := cross(u, c) - s*z;

    return .{
        _11 = r0.x, _12 = r1.x, _13 = r2.x, _14 = r3.x,
        _21 = r0.y, _22 = r1.y, _23 = r2.y, _24 = r3.y,
        _31 = r0.z, _32 = r1.z, _33 = r2.z, _34 = r3.z,
        _41 = -dot(b, t), _42 = dot(a, t), _43 = -dot(d, s), _44 = dot(c, s)
    };  
}

Mat4XVec4 :: (m: Matrix4, v: Vector4) -> Vector4 {
    result: Vector4 = ---;
    result.x = m._11 * v.x + m._21 * v.y + m._31 * v.z + m._41 * v.w;
    result.y = m._12 * v.x + m._22 * v.y + m._32 * v.z + m._42 * v.w;
    result.z = m._13 * v.x + m._23 * v.y + m._33 * v.z + m._43 * v.w;
    result.w = m._14 * v.x + m._24 * v.y + m._34 * v.z + m._44 * v.w;
    return result;
}

vec3toVec4 :: (v : Vector3) -> Vector4 {
    return .{v.x, v.y, v.z, 1.0};
}

// TODO: Use Trace in collision.jai when the proc is hardened
PickTri :: (camera : Camera, screenSpaceXY : Vector2, clientWidth : u32, clientHeight : u32, world : [] Model) -> bool, Tri, float {
    // Get Worldspace coordinates of target
    viewMat := CreateView(camera);
    // viewMat = make_look_at_matrix(camera.pos, camera.center, camera.up, x_is_forward=false);

    projMat := Perspective(camera.fov * PI / 180.0, clientWidth / cast(float)clientHeight, 0.1, 1000.0);
    // projMat = make_projection_matrix(camera.fov * PI / 180.0, clientWidth / cast(float)clientHeight, 0.1, 1000.0);

    centerX := screenSpaceXY.x - cast(float)clientWidth / 2.0;
    centerY := screenSpaceXY.y - cast(float)clientHeight / 2.0;
    
    Xndc := centerX / (cast(float)clientWidth / 2.0);
    Yndc := centerY / (cast(float)clientHeight / 2.0);

    // Xndc *= -camera.pos.z;
    // Yndc *= -camera.pos.z;

    // print("Camera pos: %\n", camera.pos);


    invProjMat := inverse(projMat);   
    invViewMat := inverse(viewMat);

    viewSpaceCoords := ((invProjMat) * Vector4.{Xndc, Yndc, -1.0, 0.0});
    viewSpaceCoords.z = -1.0;
    viewSpaceCoords.w = 1.0;
    worldSpaceCoords := ((invViewMat) * viewSpaceCoords);

    worldSpaceCoords3 := Vector3.{worldSpaceCoords.x, worldSpaceCoords.y, worldSpaceCoords.z};
    // print("camera.forward.z: %\n", camera.forward.z);

    // worldSpaceCoords = Mat4XVec4(transpose(toWorldSpace), Vector4.{Xndc, Yndc, -1.0, 1.0});
    // worldSpace := transpose(invViewMat) * viewSpace;
    
    r := normalize(camera.forward);
    // print("r: %\n", r);
    // r := Vector3.{worldSpaceCoords.x, worldSpaceCoords.y, camera.forward.z};
    // r = normalize(r);
    shortestT := 999.99;
    testTri := Tri.{
        .{pos = .{  0.0, 0.0, 0.0}, uv = .{0.0, 0.0}, bc = .{1.0, 0.0, 0.0}, normal = .{0.0, 0.0, 1.0}},
        .{pos = .{  1.0, 0.0, 0.0}, uv = .{1.0, 0.0}, bc = .{0.0, 1.0, 0.0}, normal = .{0.0, 0.0, 1.0}},
        .{pos = .{  1.0, 1.0, 0.0}, uv = .{1.0, 1.0}, bc = .{0.0, 0.0, 1.0}, normal = .{0.0, 0.0, 1.0}}
    };
    modelToCheck : Model;
    bestTri : Tri;
    success := false;
    for model : world {
        for tri : model.tris {            
            // tri := testTri;
            n := tri.a.normal; // NOTE: The normal could be an average between two vertex-normals but for now we only have hard surfaces.
            c := normalize(camera.pos - tri.a.pos); 
            nDotC := dot(n, c);
            if nDotC >= 0 { // Is camera pos on the positive (front side) of the plane?
                nDotR := dot(n, r);
                if nDotR < 0.0 { // Is the ray looking to the front face of the plane? Must be *really* smaller than 0 because later we divide by  nDotR!
                    // if nDotR >= -0.00001 && nDotR <= 0.00001 continue;
                    // compute the hitpoint p between ray and plane
                    d := -dot(n, tri.a.pos);
                    t := (-dot(n, camera.pos) - d) / nDotR;
                    p := camera.pos + t*r;
                    // if t < shortestT {
                        modelToCheck = model;
                        
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
                    // }
                }
            }
        }
    }

    hitPoint := camera.pos + (shortestT*r);
    // print("t: %, hitPoint: %, bestTri: %\n", shortestT, hitPoint, bestTri);
    // print("bestTri: %\n", bestTri);
    // print("canera.pos: % || shortestT: %\n", camera.pos, shortestT);

    return success, bestTri, shortestT;
    
    // return .{Xnd, Ynd, 0.0, 0.0};
}