
#scope_file

cameraEntities : [..] Entity(Camera);
bigEntities    : [..] Entity(BigEntity);

#scope_export

BaseEntity :: struct {
    type        : Type;
    position    : Vector3;

    HandleInput : (self : *BaseEntity);
}

Entity :: struct ($X : Type) {
    #as using base : BaseEntity;

    base.type = X;

    instance : X;
}

CallInputHandlers :: () {
    for cameraEntities {
        it.HandleInput(*it);
    }
}

SetEntityInputHandler :: (self : *BaseEntity, InputHandlerProc : (self : *BaseEntity)) {
    self.HandleInput = InputHandlerProc;
}

CreateEntity :: ($X : Type) -> *BaseEntity {
    if X == Camera {
        camera := CreateCamera(Vector3.{10.0, -10.0, 1000.0}, Camera.{ fov = 50.0 });
        camera.HandleInput = CameraInputHandler;
        array_add(*cameraEntities, camera);
        return *cameraEntities[cameraEntities.count - 1];
    }

    return null;
}
