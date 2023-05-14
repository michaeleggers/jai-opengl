// TODO: Make use of the orientation quaternion. At least Quaternions provide
//       this feature of easily accumulating rotations. But we don't use it yet...

#import "Basic";
#import "Math";


Camera :: struct {
    pos     := Vector3.{ 0.0, 0.0, 3.0 };
    center  := Vector3.{ 0.0, 0.0, 0.0 };
    up      := Vector3.{ 0.0, 1.0, 0.0 };   
    forward : Vector3;
    orientation : Quaternion;    
    fov     := 90.0;
}

CreateCamera :: (camera : Camera) -> Camera {
    result := camera;
    result.forward = normalize(result.center - result.pos);    
    SetOrientation(*result);

    return result;
}

SetOrientation :: (using camera : *Camera) {
    qUp : Quaternion;
    qRight : Quaternion;
    set_from_axis_and_angle(*qUp, up, 0.0);
    right := normalize(cross(forward, up));
    set_from_axis_and_angle(*qRight, right, 0.0);

    orientation = qUp*qRight;
}

CreateView :: (using camera : Camera) -> Matrix4 {    
    result := LookAt(pos, center, up);

    return result;
}

MoveSide :: (using camera : *Camera, distance : float) {
    right := normalize(cross(forward, up));
    pos += distance * right;
    center = pos + forward;
}

MoveForward :: (using camera : *Camera, distance : float) {
    pos += distance * forward;
    center = pos + forward;
}

RotateAroundUp :: (using camera : *Camera, angle : float) {
    refUpQ : Quaternion;
    set_from_axis_and_angle(*refUpQ, .{0.0, 1.0, 0.0}, angle);

    rotate(*forward, refUpQ);
    rotate(*up, refUpQ);
    center = pos + forward;
    orientation = refUpQ * orientation;
}

RotateAroundSide :: (using camera : *Camera, angle : float) {
    refRightQ : Quaternion;
    right := normalize(cross(forward, up));
    set_from_axis_and_angle(*refRightQ, right, angle);

    rotate(*up, refRightQ);
    rotate(*forward, refRightQ);
    center = pos + forward;
    orientation = refRightQ * orientation;
}
