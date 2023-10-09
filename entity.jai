
#scope_file

cameraEntities     : [..] Entity(Camera);
bigEntities        : [..] Entity(BigEntity);
g_EntitySpawnTable : Table(string, EntityCreateStruct);

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


// TODO: Good idea but maybe doesn't work and even more complicated than neccessary!
#run {
    table_add(*g_EntitySpawnTable, "info_player_start", EntityCreateStruct.{type = BigEntity, classname = "info_player_start"});
    cs, found := table_find(*g_EntitySpawnTable, "info_player_start");
    print("%\n", found);
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
