
BaseEntity :: struct {
    VirtualUpdateOnKeys : (*BaseEntity, [] bool) -> () = null; 
}

UpdateOnKeys :: (baseEntity : *BaseEntity, keyState : [] bool) {
    baseEntity.VirtualUpdateOnKeys(baseEntity, keyState);
}
