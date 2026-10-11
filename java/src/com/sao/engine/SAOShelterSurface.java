package com.sao.engine;

import java.lang.ref.WeakReference;
import java.util.*;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.SpriteDetails.IsoObjectType;

/** Personally observed walking surfaces and existing access for a retained shelter concern. */
public final class SAOShelterSurface {
    private SAOShelterSurface() { }
    private static final int[][] SIDES={{0,-1},{-1,0},{0,1},{1,0}};
    private static final Map<SAOIsoPlayerShell,LinkedHashMap<String,Surface>> SITES=new WeakHashMap<>();
    private static KahluaTable table(){return LuaManager.platform.newTable();}
    private static void put(KahluaTable row,String key,int value){row.rawset(key,(double)value);}
    private static boolean visible(SAOIsoPlayerShell body,IsoGridSquare square){return SAOPerceptionScanner.canSeeWorldSquareNow(body,square,8);}
    private static boolean approach(SAOIsoPlayerShell body,IsoGridSquare square){
        if(square==null||!square.isSolidFloor()||square.isSolid()||square.isSolidTrans()||!square.isFree(false)
            ||square.HasStairs()||square.haveFire()||square.isVehicleIntersecting())return false;
        for(var other:square.getMovingObjects())if(other!=body&&other.isCharacter())return false;
        return true;
    }
    private static boolean missing(SAOIsoPlayerShell body,IsoGridSquare square){
        return square!=null&&visible(body,square)&&!square.isSolidFloor()&&!square.HasStairsBelow()&&square.connectedWithFloor();
    }
    private static boolean sameShelter(IsoGridSquare eye,IsoGridSquare square){
        if(eye.getRoom()!=null)return square.getRoom()==eye.getRoom();
        var region=eye.getIsoWorldRegion();return region instanceof zombie.iso.areas.isoregion.regions.IsoWorldRegion nativeRegion
            &&nativeRegion.isEnclosed()&&square.getIsoWorldRegion()==region;
    }
    private static final class Surface {
        final String actor,key,revision=UUID.randomUUID().toString();
        final int x,y,z,ax,ay;
        final WeakReference<IsoGridSquare> square,approach;
        final ArrayList<WeakReference<IsoObject>> objects=new ArrayList<>();
        Surface(String actor,IsoGridSquare square,IsoGridSquare approach){
            this.actor=actor;x=square.getX();y=square.getY();z=square.getZ();ax=approach.getX();ay=approach.getY();
            key="shelter-surface:"+x+":"+y+":"+z;
            for(int i=0;i<square.getObjects().size();i++)objects.add(new WeakReference<>(square.getObjects().get(i)));
            this.square=new WeakReference<>(square);this.approach=new WeakReference<>(approach);
        }
        boolean current(SAOIsoPlayerShell body,String actor){
            var sq=square.get();var at=approach.get();
            if(!this.actor.equals(actor)||sq==null||at==null||body.getCell().getGridSquare(x,y,z)!=sq
                ||body.getCell().getGridSquare(ax,ay,z)!=at||Math.floor(body.getZ())!=z||!missing(body,sq)
                ||!SAOShelterSurface.approach(body,at)||!visible(body,at)||objects.size()!=sq.getObjects().size())return false;
            for(int i=0;i<objects.size();i++)if(objects.get(i).get()!=sq.getObjects().get(i))return false;
            return true;
        }
    }
    public static synchronized KahluaTable observe(SAOIsoPlayerShell body){
        var out=table();String actor=SAOConceptObservation.actor(body);if(actor==null)return out;
        var eye=body.getCurrentSquare();var sites=SITES.computeIfAbsent(body,b->new LinkedHashMap<>());int count=0;
        boolean withinShelter=eye.getRoom()!=null||eye.getIsoWorldRegion() instanceof zombie.iso.areas.isoregion.regions.IsoWorldRegion region&&region.isEnclosed();
        for(int radius=0;radius<=8;radius++)for(int dx=-radius;dx<=radius;dx++)for(int dy=-radius;dy<=radius;dy++){
            if(Math.max(Math.abs(dx),Math.abs(dy))!=radius||count>=32)continue;
            var sq=body.getCell().getGridSquare(eye.getX()+dx,eye.getY()+dy,eye.getZ());if(!missing(body,sq)
                ||withinShelter&&!sameShelter(eye,sq))continue;
            IsoGridSquare best=null;double distance=Double.POSITIVE_INFINITY;
            for(int[] side:SIDES){var at=body.getCell().getGridSquare(sq.getX()+side[0],sq.getY()+side[1],sq.getZ());
                if(!approach(body,at)||!visible(body,at)||at.isWallTo(sq)||at.isDoorTo(sq)||at.isWindowTo(sq)||at.isHoppableTo(sq))continue;
                double d=Math.hypot(body.getX()-at.getX()-.5,body.getY()-at.getY()-.5);if(d<distance){best=at;distance=d;}}
            if(best==null)continue;
            String key="shelter-surface:"+sq.getX()+":"+sq.getY()+":"+sq.getZ();var site=sites.get(key);
            if(site==null||!site.current(body,actor)||site.ax!=best.getX()||site.ay!=best.getY()){site=new Surface(actor,sq,best);sites.put(key,site);}
            var row=table();row.rawset("key",key);row.rawset("revision",site.revision);row.rawset("face","W");row.rawset("mode","floor");
            row.rawset("supported",true);row.rawset("missingFloor",true);put(row,"x",site.x);put(row,"y",site.y);put(row,"z",site.z);
            put(row,"approachX",site.ax);put(row,"approachY",site.ay);put(row,"approachZ",site.z);out.rawset((double)++count,row);
        }
        while(sites.size()>64)sites.remove(sites.keySet().iterator().next());return out;
    }
    private static Surface known(SAOIsoPlayerShell body,String key,String revision){
        String actor=SAOConceptObservation.actor(body);var sites=SITES.get(body);var site=sites==null?null:sites.get(key);
        return actor!=null&&site!=null&&site.revision.equals(revision)&&site.current(body,actor)?site:null;
    }
    public static synchronized IsoGridSquare placement(SAOIsoPlayerShell body,String key,String revision){
        var site=known(body,key,revision);return site!=null&&body.getCurrentSquare()==site.approach.get()
            &&Math.hypot(body.getX()-site.ax-.5,body.getY()-site.ay-.5)<=.35?site.square.get():null;
    }
    public static boolean created(SAOIsoPlayerShell body,IsoObject object,String entity,int x,int y,int z){
        var square=body.getCell().getGridSquare(x,y,z);
        return SAOConceptObservation.actor(body)!=null&&square!=null&&object!=null&&object.getSquare()==square&&object.getObjectIndex()>=0
            &&square.getObjects().contains(object)&&square.isSolidFloor()&&object.getProperties().has(IsoFlagType.solidfloor)
            &&object.getEntityScript()!=null&&object.getEntityScript().getFullName().equals(entity)
            &&Set.of("Base.WoodFloorLvl1","Base.WoodFloorLvl2","Base.WoodFloorLvl3").contains(entity)&&visible(body,square);
    }
    public static KahluaTable coverNeeds(SAOIsoPlayerShell body){
        var out=table();if(SAOConceptObservation.actor(body)==null)return out;var eye=body.getCurrentSquare();int count=0;
        for(int radius=0;radius<=8;radius++)for(int dx=-radius;dx<=radius;dx++)for(int dy=-radius;dy<=radius;dy++){
            if(Math.max(Math.abs(dx),Math.abs(dy))!=radius||count>=32)continue;
            var sq=body.getCell().getGridSquare(eye.getX()+dx,eye.getY()+dy,eye.getZ());
            if(sq==null||!visible(body,sq)||!approach(body,sq)||!sameShelter(eye,sq))continue;
            var row=table();put(row,"x",sq.getX());put(row,"y",sq.getY());put(row,"z",sq.getZ());row.rawset("roof",sq.haveRoof);out.rawset((double)++count,row);
        }return out;
    }
    public static KahluaTable access(SAOIsoPlayerShell body){
        var out=table();if(SAOConceptObservation.actor(body)==null)return out;var eye=body.getCurrentSquare();int count=0;
        for(int dx=-8;dx<=8;dx++)for(int dy=-8;dy<=8;dy++){
            var square=body.getCell().getGridSquare(eye.getX()+dx,eye.getY()+dy,eye.getZ());if(!visible(body,square))continue;
            for(int i=0;i<square.getObjects().size();i++){
                var object=square.getObjects().get(i);var type=object.getType();if(type!=IsoObjectType.stairsTN&&type!=IsoObjectType.stairsTW)continue;
                if(count>=16)return out;var row=table();row.rawset("key","shelter-stair:"+square.getX()+":"+square.getY()+":"+square.getZ()+":"+type);
                put(row,"x",square.getX());put(row,"y",square.getY());put(row,"z",square.getZ());
                put(row,"landingX",square.getX()-(type==IsoObjectType.stairsTW?1:0));put(row,"landingY",square.getY()-(type==IsoObjectType.stairsTN?1:0));
                put(row,"landingZ",square.getZ()+1);row.rawset("landingObserved",false);row.rawset("basis","visible-native-stair-top");out.rawset((double)++count,row);
            }
        }return out;
    }
}
