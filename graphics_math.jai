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