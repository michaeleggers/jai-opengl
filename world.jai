
gEntities : [..] Entity;

World :: struct {
    models : [..] Model; // World geometry
    player : Entity;
}

SpawnEntities :: (entities : [] Entity, refdef : *RefDef, world : *World) {
    for entity : entities {
        if entity.type == .PLAYER {
            world.player = entity;
            world.player.textureID = RegisterTexture(entity.texture);
            world.player.modelID = CreateEntityModel(GEOM_UNIT_CUBE);
            RenderAddEntity(refdef, world.player);
        }
    }
}