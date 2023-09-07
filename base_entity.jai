
BaseEntity :: struct {    
    VirtualUpdateOnKeys : (*BaseEntity, frameTime : float) -> () = null; 
}

UpdateOnKeys :: (baseEntity : *BaseEntity, frameTime : float) {
    baseEntity.VirtualUpdateOnKeys(baseEntity, frameTime);
}
