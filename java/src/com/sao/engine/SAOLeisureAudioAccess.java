package com.sao.engine;

import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.iso.IsoGridSquare;
import zombie.iso.objects.IsoWorldInventoryObject;
import zombie.vehicles.BaseVehicle;
import zombie.vehicles.VehiclePart;

/** Fresh actor-acquired physical targets; source device state stays with its owner. */
public final class SAOLeisureAudioAccess {
    private SAOLeisureAudioAccess() { }
    private static String instance(Object value) {
        return Integer.toHexString(System.identityHashCode(value));
    }
    private static KahluaTable row(SAOIsoPlayerShell body,String key,String expectedInstance) {
        if(key==null||key.length()>160||expectedInstance==null)return null;
        KahluaTable view=SAOConceptObservation.observe(body,8);
        if(view==null||!(view.rawget("observations") instanceof KahluaTable rows))return null;
        for(int n=1;n<=rows.len();n++){
            if(rows.rawget((double)n) instanceof KahluaTable row
                    &&key.equals(row.rawget("key"))&&expectedInstance.equals(row.rawget("runtimeInstance")))return row;
        }
        return null;
    }
    private static IsoGridSquare square(SAOIsoPlayerShell body,KahluaTable row) {
        if(!(row.rawget("x") instanceof Number x)||!(row.rawget("y") instanceof Number y)
                ||!(row.rawget("z") instanceof Number z))return null;
        return body.getCell().getGridSquare(x.intValue(),y.intValue(),z.intValue());
    }
    private static boolean itemMatches(KahluaTable row,zombie.inventory.InventoryItem item){
        return item!=null&&Long.toString(item.getID()).equals(row.rawget("itemKey"))
            &&item.getFullType().equals(row.rawget("itemType"));
    }
    public static KahluaTable resolve(SAOIsoPlayerShell body,String key,String expectedInstance) {
        KahluaTable row=row(body,key,expectedInstance);
        if(row==null)return null;
        KahluaTable result=LuaManager.platform.newTable();
        if("worldObjects".equals(row.rawget("objectCollection"))){
            IsoGridSquare square=square(body,row);
            if(square==null||!(row.rawget("objectIndex") instanceof Number index))return null;
            int i=index.intValue();
            if(i<0||i>=square.getWorldObjects().size())return null;
            IsoWorldInventoryObject object=square.getWorldObjects().get(i);
            if(object==null||object.getSquare()!=square||!expectedInstance.equals(instance(object))
                    ||!itemMatches(row,object.getItem())||object.getItem().getWorldItem()!=object)return null;
            result.rawset("object",object);result.rawset("item",object.getItem());
            return result;
        }
        if(!"vehicle".equals(row.rawget("objectCollection"))
                ||!(row.rawget("vehicleId") instanceof Number id)
                ||!(row.rawget("vehicleSqlId") instanceof Number sqlId))return null;
        var vehicles=new java.util.ArrayList<BaseVehicle>(body.getCell().getVehicles());
        var occupied=body.getVehicle();
        if(occupied!=null&&!vehicles.contains(occupied))vehicles.add(occupied);
        for(BaseVehicle vehicle:vehicles){
            if(vehicle==null||vehicle.getId()!=id.intValue()||vehicle.getSqlId()!=sqlId.intValue()
                    ||!instance(vehicle).equals(row.rawget("vehicleRuntimeInstance")))continue;
            var parts=vehicle.getParts();if(parts==null)return null;
            for(int i=0;i<parts.size();i++){
                VehiclePart part=parts.get(i);
                if(part==null||!"Radio".equals(part.getId())||part.getVehicle()!=vehicle
                        ||!expectedInstance.equals(instance(part))
                        ||!instance(part).equals(row.rawget("partRuntimeInstance")))continue;
                var item=part.getInventoryItem();
                if(row.rawget("itemKey")!=null&&!itemMatches(row,item))return null;
                if(row.rawget("itemKey")==null&&item!=null)return null;
                result.rawset("vehicle",vehicle);result.rawset("part",part);return result;
            }
            return null;
        }
        return null;
    }
    public static boolean canHear(SAOIsoPlayerShell body,String key,String expectedInstance,float range) {
        KahluaTable target=resolve(body,key,expectedInstance);
        if(target==null)return false;
        if(target.rawget("object") instanceof IsoWorldInventoryObject object)
            return SAOPerceptionScanner.canHearSourceNow(body,object.getSquare(),range);
        if(target.rawget("vehicle") instanceof BaseVehicle vehicle)
            return SAOPerceptionScanner.canHearSourceNow(body,vehicle.getSquare(),range);
        return false;
    }
}
