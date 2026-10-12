package com.sao.engine;

import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoFlagType;

/** Person-visible loaded furniture and local clearance. No action or permission. */
public final class SAOFurnitureObservation {
    private SAOFurnitureObservation() { }
    public static KahluaTable observe(SAOIsoPlayerShell body, int radius) {
        String actor=SAOConceptObservation.actor(body);
        if(actor==null || radius<1 || radius>8)return null;
        var result=LuaManager.platform.newTable();var squares=LuaManager.platform.newTable();
        result.rawset("schema","sao.person-furniture-observation/1");result.rawset("actorId",actor);
        result.rawset("status","available");result.rawset("squares",squares);
        var eye=body.getCurrentSquare();int count=0;
        for(int r=0;r<=radius;r++)for(int dx=-r;dx<=r;dx++)for(int dy=-r;dy<=r;dy++) {
            if(Math.max(Math.abs(dx),Math.abs(dy))!=r || count>=256)continue;
            var square=body.getCell().getGridSquare(eye.getX()+dx,eye.getY()+dy,eye.getZ());
            if(!SAOPerceptionScanner.canSeeWorldSquareNow(body,square,radius))continue;
            var row=LuaManager.platform.newTable();var objects=LuaManager.platform.newTable();
            row.rawset("x",(double)square.getX());row.rawset("y",(double)square.getY());row.rawset("z",(double)square.getZ());
            row.rawset("floor",square.isSolidFloor());row.rawset("free",square.isFree(false));
            row.rawset("stairs",square.HasStairs() || square.HasStairsBelow());row.rawset("objects",objects);
            boolean occupied=false;for(var moving:square.getMovingObjects())if(moving!=body && moving.isCharacter())occupied=true;
            row.rawset("occupied",occupied);
            for(int i=0;i<square.getObjects().size() && i<64;i++) {
                IsoObject object=square.getObjects().get(i);if(object.getSprite()==null || object.getSprite().getName()==null)continue;
                var o=LuaManager.platform.newTable();o.rawset("index",(double)i);
                o.rawset("identity",Integer.toHexString(System.identityHashCode(object)));
                o.rawset("sprite",object.getSprite().getName());
                o.rawset("bed",object.getProperties().has(IsoFlagType.bed));
                o.rawset("facing",object.getProperties().get("Facing"));o.rawset("bedType",object.getProperties().get("BedType"));
                o.rawset("recoverySource",SAORecoveryPlace.visibleSourceKey(body,object,radius));
                o.rawset("solid",object.getProperties().has(IsoFlagType.solid) || object.getProperties().has(IsoFlagType.solidtrans));
                o.rawset("movable",object.getProperties().has("IsMoveAble"));
                var grid=object.getSprite().getSpriteGrid();
                if(grid!=null) {
                    o.rawset("gridWidth",(double)grid.getWidth());o.rawset("gridHeight",(double)grid.getHeight());
                    o.rawset("gridX",(double)grid.getSpriteGridPosX(object.getSprite()));
                    o.rawset("gridY",(double)grid.getSpriteGridPosY(object.getSprite()));
                }
                objects.rawset((double)objects.len()+1,o);
            }
            squares.rawset((double)++count,row);
        }
        return result;
    }
}
