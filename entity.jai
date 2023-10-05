
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

SetEntityInputHandler :: (self : *BaseEntity, InputHandlerProc : (self : *BaseEntity)) {
    self.HandleInput = InputHandlerProc;
}
