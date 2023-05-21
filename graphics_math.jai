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

PickTri :: (camera : Camera, screenSpaceXY : Vector2, clientWidth : u32, clientHeight : u32, world : [] Model) -> Vector4 {
    // Get Worldspace coordinates of target
    viewMat := CreateView(camera);
    // viewMat = make_look_at_matrix(camera.pos, camera.center, camera.up, x_is_forward=false);

    projMat := Perspective(camera.fov * PI / 180.0, clientWidth / cast(float)clientHeight, 0.1, 1000.0);
    // projMat = make_projection_matrix(camera.fov * PI / 180.0, clientWidth / cast(float)clientHeight, 0.1, 1000.0);

    centerX := screenSpaceXY.x - cast(float)clientWidth / 2.0;
    centerY := screenSpaceXY.y - cast(float)clientHeight / 2.0;
    
    Xndc := centerX / (cast(float)clientWidth / 2.0);
    Yndc := centerY / (cast(float)clientHeight / 2.0);

    Xndc *= -camera.pos.z;
    Yndc *= -camera.pos.z;

    print("Camera pos: %\n", camera.pos);

    invProjMat := Inverse(projMat);
    ident := invProjMat * projMat;
    // print("Ident: %\n\n\n", ident);
    invViewMat := Inverse(viewMat);
    //toWorldSpace := invViewMat * invProjMat;

    viewSpaceCoords := (invProjMat * Vector4.{Xndc, Yndc, -1.0, 1.0});
    worldSpaceCoords := (invViewMat * viewSpaceCoords);

    // worldSpaceCoords = Mat4XVec4(transpose(toWorldSpace), Vector4.{Xndc, Yndc, -1.0, 1.0});
    // worldSpace := transpose(invViewMat) * viewSpace;
        
    return worldSpaceCoords;
    
    // return .{Xnd, Ynd, 0.0, 0.0};
}