
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

EntityCreateStruct :: struct {
    type      : Type;
    classname : string;
    position  : Vector3;
}

CallInputHandlers :: () {
    for cameraEntities {
        it.HandleInput(*it);
    }
}

UpdateEntity :: (baseEntity : *BaseEntity) {
    if baseEntity.type == BigEntity {
        UpdateBigEntity(cast(*Entity(BigEntity))baseEntity);
    }
}

SetEntityInputHandler :: (self : *BaseEntity, InputHandlerProc : (self : *BaseEntity)) {
    self.HandleInput = InputHandlerProc;
}

CreateEntity :: (createStruct : EntityCreateStruct = .{}) -> *BaseEntity {
    type := createStruct.type;
    if type == Camera {
        camera := CreateCamera(Vector3.{10.0, -10.0, 1000.0}, Camera.{ fov = 50.0 });
        camera.HandleInput = CameraInputHandler;
        array_add(*cameraEntities, camera);
        return *cameraEntities[cameraEntities.count - 1];
    } else if type == BigEntity {
        modelname := GetModelNameByClassname(createStruct.classname);
        iqmModelPath := tprint("assets/models/%/%.iqm", modelname, modelname);
        bigEntity := CreateBigEntity(iqmModelPath, createStruct.position);
        array_add(*bigEntities, bigEntity);
        return *bigEntities[bigEntities.count - 1];
    }

    return null;
}
