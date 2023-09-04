
BaseEntity :: struct {    
    VirtualUpdateOnKeys : (*BaseEntity) -> () = null; 
}

UpdateOnKeys :: (baseEntity : *BaseEntity) {
    baseEntity.VirtualUpdateOnKeys(baseEntity);
}
