
BaseEntity :: struct {
    type        : Type;
    position    : Vector3;

    HandleInput : (key : KeyboardButton);
}

Entity :: struct ($X : Type) {
    #as using base : BaseEntity;

    type = X;
    instance : X;
}

SetEntityInputHandler :: (entity : *BaseEntity, InputHandlerProc : (key : KeyboardButton)) {
    entity.HandleInput = InputHandlerProc;
}
