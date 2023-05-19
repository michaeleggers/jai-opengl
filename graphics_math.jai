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

Inverse :: (m : Matrix4) -> Matrix4 {
    result : Matrix4;
    inv : [16] float;
    det : float;

    inv[0] = m._22 * m._33 * m._44 -
             m._22 * m._34 * m._43 -
             m._32 * m._23 * m._44 +
             m._32 * m._24  * m._43 +
             m._42 * m._23  * m._34 - 
             m._42 * m._24 * m._33;

    inv[4] = -m._21  * m._33 * m._44 + 
            m._21  * m._34 * m._43 + 
            m._31  * m._23  * m._44 - 
            m._31  * m._24  * m._43 - 
            m._41 * m._23  * m._34 + 
            m._41 * m._24  * m._33;

    inv[8] = m._21  * m._32 * m._44 - 
        m._21  * m._34 * m._42 - 
        m._31  * m._22 * m._44 + 
        m._31  * m._24 * m._42 + 
        m._41 * m._22 * m._34 - 
        m._41 * m._24 * m._32;       

    inv[12] = -m._21 * m._32 * m._43 + 
        m._21 * m._33 * m._42 +
        m._31 * m._22 * m._43 - 
        m._31 * m._23 * m._42 - 
        m._41 * m._22 * m._33 + 
        m._41 * m._23 * m._32;

    det = m._11 * inv[0] + m._12 * inv[4] + m._13 * inv[8] + m._14 * inv[12];

    assert (det != 0, "matrix not invertible. Determinant is %\n", det);

    det = 1.0 / det;

    for i : 0..3 {
        inv[i] = inv[i] * det;
        inv[i + 4] = inv[i + 4] * det;
        inv[i + 8] = inv[i + 8] * det;
        inv[i + 12] = inv[i + 12] * det;
    }

    for i : 0..3 {
        for j : 0..3 {
            result.coef[j][i] = inv[i + j*4];
        }
    }

    return result;
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
    projMat := Perspective(camera.fov * PI / 180.0, clientWidth / cast(float)clientHeight, 0.1, 1000.0);
    centerX := screenSpaceXY.x - cast(float)clientWidth / 2.0;
    centerY := screenSpaceXY.y - cast(float)clientHeight / 2.0;
    
    Xnd := centerX / (cast(float)clientWidth / 2.0);
    Ynd := centerY / (cast(float)clientHeight / 2.0);
    invProjMat := inverse(transpose(projMat));
    invViewMat := inverse(transpose(viewMat));

    viewSpace := transpose(invProjMat) * Vector4.{Xnd, Ynd, 0.0, 1.0};
    worldSpace := transpose(invViewMat) * viewSpace;
    
    
    return worldSpace;
    
    // return .{Xnd, Ynd, 0.0, 0.0};
}