// TODO: Make use of the orientation quaternion. At least Quaternions provide
//       this feature of easily accumulating rotations. But we don't use it yet...

#import "Basic";
#import "Math";


Camera :: struct {
    #as using base := BaseEntity.{
        VirtualUpdateOnKeys = (baseEntity : *BaseEntity, keyState : [] bool) {
            using cast(*Camera)baseEntity;
            if KeyPressed(KEYBOARD_RIGHT)     RotateAroundUp(cast(*Camera)baseEntity, -0.0001);
            if KeyPressed(KEYBOARD_LEFT)      RotateAroundUp(cast(*Camera)baseEntity,  0.0001);
            if KeyPressed(KEYBOARD_UP)        RotateAroundSide(cast(*Camera)baseEntity,  0.0001);
            if KeyPressed(KEYBOARD_DOWN)      RotateAroundSide(cast(*Camera)baseEntity, -0.0001);
            if KeyPressed(KEYBOARD_D)         MoveSide(cast(*Camera)baseEntity,  0.1);
            if KeyPressed(KEYBOARD_A)         MoveSide(cast(*Camera)baseEntity, -0.1);
            if KeyPressed(KEYBOARD_W)         MoveForward(cast(*Camera)baseEntity,  0.1);
            if KeyPressed(KEYBOARD_S)         MoveForward(cast(*Camera)baseEntity, -0.1);
        }
    };
    type    : Type = Camera;
    pos     := Vector3.{ 0.0, 0.0, 5.0 };
    center  := Vector3.{ 0.0, 0.0, 0.0 };
    up      := Vector3.{ 0.0, 0.0, 1.0 };   
    forward : Vector3;
    orientation : Quaternion;    
    fov     := 90.0;
}

FollowCamera :: struct {
    #as using camera : Camera;
    type = FollowCamera;
    base = BaseEntity.{
        VirtualUpdateOnKeys = null
    };
    target  : *Entity = null;
    distance := 5.0;
}

CreateFollowCamera :: (camera : Camera, target : *Entity, distance : float) -> FollowCamera {
    result : FollowCamera;    
    result.distance = distance;
    result.pos = camera.pos;
    result.center = target.pos;
    result.up = camera.up;
    result.fov = camera.fov;
    print("target.pos: %\n", target.pos);
    result.forward = normalize(target.pos - result.pos);
    SetOrientation(*result);
    result.target = target;

    return result;
}

UpdateFollowCamera :: (using followCamera : *FollowCamera) {
    pos = target.pos + distance*(-forward);
    center = target.pos;
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
    set_from_axis_and_angle(*refUpQ, .{0.0, 0.0, 1.0}, angle);

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
