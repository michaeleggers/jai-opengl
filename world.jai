
gEntities : [..] Entity; // TODO: What is this?

World :: struct {
    models : [..] Model; // World geometry
    player : Entity;
}

SpawnEntities :: (entities : [] Entity, refdef : *RefDef, world : *World) {
    for entity : entities {
        if entity.type == .PLAYER { // TODO: Actually load model data from disk and compute necessary stuff as AABB.
            world.player = entity;
            world.player.textureID = RegisterTexture(entity.texture);
            world.player.modelID = CreateEntityModel(GEOM_UNIT_CUBE);
            world.player.aabb = ComputeAABB(GEOM_UNIT_CUBE);
        }
    }
}

UpdateWorld :: (refdef : *RefDef, world : *World) {
    aabb := world.player.aabb;

    Draw3DImmediateLinesPtr(aabb.debugLines, 12); // TODO: This is probably the most C way of doing this. And it is... ugly. Maybe
    // we should just not use immediate draw for that many lines and just create a AABB VAO, VBO. Not sure...
    RenderAddEntity(refdef, world.player);
}
