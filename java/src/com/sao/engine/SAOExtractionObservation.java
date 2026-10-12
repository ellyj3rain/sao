package com.sao.engine;

import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.inventory.InventoryItem;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.objects.IsoTree;

/** Exact person-visible extraction source and current items; no mutation or claim. */
public final class SAOExtractionObservation {
    private SAOExtractionObservation() { }
    private static String identity(Object value) {
        return Integer.toHexString(System.identityHashCode(value));
    }
    private static KahluaTable item(InventoryItem value) {
        var row=LuaManager.platform.newTable();
        row.rawset("id",Integer.toString(value.getID()));
        row.rawset("identity",identity(value));row.rawset("type",value.getFullType());
        row.rawset("uses",(double)value.getCurrentUses());row.rawset("fraction",(double)value.getCurrentUsesFloat());
        row.rawset("condition",(double)value.getCondition());
        return row;
    }
    /** The caller retains the actual source/square handles across its native call.
     * A removed source can be measured only on that still-visible loaded square. */
    public static KahluaTable observeExact(SAOIsoPlayerShell body,IsoObject source,IsoGridSquare square,int radius) {
        String actor=SAOConceptObservation.actor(body);
        if(actor==null || source==null || square==null || radius<1 || radius>8
                || body.getCell().getGridSquare(square.getX(),square.getY(),square.getZ())!=square
                || !SAOPerceptionScanner.canSeeWorldSquareNow(body,square,radius))return null;
        boolean present=square.getObjects().contains(source) && source.getObjectIndex()>=0;
        if(source.getSquare()!=null && source.getSquare()!=square)return null;
        if(source.getObjectIndex()>=0 && !present)return null;
        var row=LuaManager.platform.newTable();
        row.rawset("schema","sao.person-extraction-observation/1");row.rawset("actorId",actor);
        row.rawset("bodyIdentity",identity(body));row.rawset("sourceIdentity",identity(source));
        row.rawset("squareIdentity",identity(square));row.rawset("present",present);
        row.rawset("x",(double)square.getX());row.rawset("y",(double)square.getY());row.rawset("z",(double)square.getZ());
        row.rawset("kind",source instanceof IsoTree ? "tree" : "ground");
        row.rawset("sourceId","extraction:"+(source instanceof IsoTree ? "tree:" : "ground:")
            +square.getX()+","+square.getY()+","+square.getZ()+":"+identity(source));
        row.rawset("persistentObjectIdentity",false);
        if(source.getSprite()!=null)row.rawset("sprite",source.getSprite().getName());
        if(source instanceof IsoTree tree) {
            row.rawset("health",(double)tree.getHealth());row.rawset("size",(double)tree.getSize());
            row.rawset("nativeLogYield",(double)tree.getLogYield());
        }
        row.rawset("shovelled",source.hasModData() && Boolean.TRUE.equals(source.getModData().rawget("shovelled")));
        var drops=LuaManager.platform.newTable();int count=0,omitted=0;
        for(var world:square.getWorldObjects()) {
            var value=world.getItem();if(value==null || world.getSquare()!=square)continue;
            if(count>=256){omitted++;continue;}
            var current=item(value);current.rawset("worldIdentity",identity(world));
            drops.rawset((double)++count,current);
        }
        row.rawset("drops",drops);row.rawset("dropOmitted",(double)omitted);
        var held=LuaManager.platform.newTable();count=0;omitted=0;
        for(var value:SAOPrivateInventory.carriedItems(body)) {
            if(count>=256){omitted++;continue;}
            held.rawset((double)++count,item(value));
        }
        row.rawset("held",held);row.rawset("heldOmitted",(double)omitted);
        var primary=body.getPrimaryHandItem();
        if(primary!=null)row.rawset("primary",item(primary));
        return row;
    }
}
