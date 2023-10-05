// TODO: Make use of the orientation quaternion. At least Quaternions provide
//       this feature of easily accumulating rotations. But we don't use it yet...

#import "Basic";
#import "Math";

#scope_file

keyState : [..] bool;
keyStatePrevFrame : [..] bool;
// Safe mouse state, so we can get a delta
mouseState : MouseState;

#scope_export


Camera :: struct {
    // #as using base := BaseEntity.{
    //     VirtualUpdateOnKeys = (baseEntity : *BaseEntity, frameTime : float) {
    //         using cast(*Camera)baseEntity;
    //         if KeyPressed(KeyboardButton.RIGHT)     RotateAroundUp(cast(*Camera)baseEntity, -(2.0*PI)/128.0);
    //         if KeyPressed(KeyboardButton.LEFT)      RotateAroundUp(cast(*Camera)baseEntity,  (2.0*PI)/128.0);
    //         if KeyPressed(KeyboardButton.UP)        RotateAroundSide(cast(*Camera)baseEntity,  (2.0*PI)/128.0);
    //         if KeyPressed(KeyboardButton.DOWN)      RotateAroundSide(cast(*Camera)baseEntity, -(2.0*PI)/128.0);
    //         if KeyPressed(KeyboardButton.D)         MoveSide(cast(*Camera)baseEntity,  1000.0*frameTime);
    //         if KeyPressed(KeyboardButton.A)         MoveSide(cast(*Camera)baseEntity, -1000.0*frameTime);
    //         if KeyPressed(KeyboardButton.W)         MoveForward(cast(*Camera)baseEntity,  1000.0*frameTime);
    //         if KeyPressed(KeyboardButton.S)         MoveForward(cast(*Camera)baseEntity, -1000.0*frameTime);
    //     }
    // };
    type    : Type = Camera;
    center  := Vector3.{ 0.0, 0.0, 0.0 };
    up      := Vector3.{ 0.0, 0.0, 1.0 };   
    forward : Vector3;
    orientation : Quaternion;    
    fov     := 90.0;
}

// FollowCamera :: struct {
//     #as using camera : Camera;
//     type = FollowCamera;
//     // base = BaseEntity.{
//     //     VirtualUpdateOnKeys = null
//     // };
//     target  : *Entity = null;
//     distance := 5.0;
// }

// CreateFollowCamera :: (camera : Camera, target : *Entity, distance : float) -> FollowCamera {
//     result : FollowCamera;    
//     result.distance = distance;
//     result.position = camera.position;
//     result.center = target.position;
//     result.up = camera.up;
//     result.fov = camera.fov;
//     print("target.pos: %\n", target.position);
//     result.forward = normalize(target.position - result.position);
//     SetOrientation(*result);
//     result.target = target;

//     return result;
// }

// UpdateFollowCamera :: (using followCamera : *Entity) {
//     pos = target.position + distance*(-forward);
//     center = target.pos;
// }

CreateCamera :: (position : Vector3, camera : Camera) -> Entity(Camera) {
    result : Entity(Camera);
    result.instance = camera;
    result.position = position;
    result.instance.forward = normalize(result.instance.center - result.position);
    SetOrientation(*result);

    return result;
}

CameraInputHandler :: (camera : *BaseEntity) {
    frameTime := getFrameTime();
    cam := cast(*Entity(Camera))camera;
    if KeyPressed(KeyboardButton.RIGHT)     RotateAroundUp(cam, -(2.0*PI)/128.0);
    if KeyPressed(KeyboardButton.LEFT)      RotateAroundUp(cam,  (2.0*PI)/128.0);
    if KeyPressed(KeyboardButton.UP)        RotateAroundSide(cam,  (2.0*PI)/128.0);
    if KeyPressed(KeyboardButton.DOWN)      RotateAroundSide(cam, -(2.0*PI)/128.0);
    if KeyPressed(KeyboardButton.D)         MoveSide(cam,  1000.0*frameTime);
    if KeyPressed(KeyboardButton.A)         MoveSide(cam, -1000.0*frameTime);
    if KeyPressed(KeyboardButton.W)         MoveForward(cam,  1000.0*frameTime);
    if KeyPressed(KeyboardButton.S)         MoveForward(cam, -1000.0*frameTime);
}

SetOrientation :: (using camera : *Entity) {
    qUp : Quaternion;
    qRight : Quaternion;
    set_from_axis_and_angle(*qUp, instance.up, 0.0);
    right := normalize(cross(instance.forward, instance.up));
    set_from_axis_and_angle(*qRight, right, 0.0);

    instance.orientation = qUp*qRight;
}

CreateView :: (using camera : Entity(Camera)) -> Matrix4 {    
    result := LookAt(position, instance.center, instance.up);

    return result;
}

MoveSide :: (using camera : *Entity(Camera), distance : float) {
    right := normalize(cross(instance.forward, instance.up));
    position += distance * right;
    instance.center = position + instance.forward;
}

MoveForward :: (using camera : *Entity, distance : float) {
    position += distance * instance.forward;
    instance.center = position + instance.forward;
}

RotateAroundUp :: (using camera : *Entity(Camera), angle : float) {

    refUpQ : Quaternion;
    set_from_axis_and_angle(*refUpQ, .{0.0, 0.0, 1.0}, angle);

    rotate(*instance.forward, refUpQ);
    rotate(*instance.up, refUpQ);
    instance.center = position + instance.forward;
    instance.orientation = refUpQ * instance.orientation;
}

RotateAroundSide :: (using camera : *Entity(Camera), angle : float) {
    refRightQ : Quaternion;
    right := normalize(cross(instance.forward, instance.up));
    set_from_axis_and_angle(*refRightQ, right, angle);

    rotate(*instance.up, refRightQ);
    rotate(*instance.forward, refRightQ);
    instance.center = position + instance.forward;
    instance.orientation = refRightQ * instance.orientation;
}
