package com.sao.engine;

import java.lang.ref.WeakReference;
import java.util.*;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoObjectType;

/** Personally acquired ground footprint; native construction owns upper clearance and landing. */
public final class SAOShelterStairs {
    private SAOShelterStairs() { }
    private static final Map<SAOIsoPlayerShell,LinkedHashMap<String,Site>> SITES=new WeakHashMap<>();
    private static KahluaTable table(){return LuaManager.platform.newTable();}
    private static void put(KahluaTable row,String key,int value){row.rawset(key,(double)value);}
    private static boolean visible(SAOIsoPlayerShell body,IsoGridSquare square){return SAOPerceptionScanner.canSeeWorldSquareNow(body,square,8);}
    private static boolean free(SAOIsoPlayerShell body,IsoGridSquare square){
        if(square==null||!visible(body,square)||!square.isSolidFloor()||square.isSolid()||square.isSolidTrans()
            ||!square.isFree(false)||square.HasStairs()||square.HasStairsBelow()||square.HasTree()
            ||square.haveFire()||square.isVehicleIntersecting())return false;
        for(var moving:square.getMovingObjects())if(moving!=body&&moving.isCharacter())return false;
        return true;
    }
    private static final class Site {
        final String actor,key,face,revision=UUID.randomUUID().toString();
        final int x,y,z,ax,ay,width,height;
        final ArrayList<WeakReference<IsoGridSquare>> squares=new ArrayList<>();
        final ArrayList<ArrayList<WeakReference<IsoObject>>> objects=new ArrayList<>();
        Site(String actor,IsoGridSquare root,IsoGridSquare approach,String face){
            this.actor=actor;this.face=face;x=root.getX();y=root.getY();z=root.getZ();ax=approach.getX();ay=approach.getY();
            width=face.equals("S")?3:1;height=face.equals("W")?3:1;key="shelter-stair-site:"+x+":"+y+":"+z+":"+face;
            for(int dx=0;dx<width;dx++)for(int dy=0;dy<height;dy++)capture(root.getCell().getGridSquare(x+dx,y+dy,z));
            capture(approach);
        }
        void capture(IsoGridSquare square){
            squares.add(new WeakReference<>(square));var held=new ArrayList<WeakReference<IsoObject>>();
            for(int n=0;n<square.getObjects().size();n++)held.add(new WeakReference<>(square.getObjects().get(n)));objects.add(held);
        }
        boolean current(SAOIsoPlayerShell body,String actor){
            if(!this.actor.equals(actor)||Math.floor(body.getZ())!=z)return false;
            for(int index=0;index<squares.size();index++){
                var square=squares.get(index).get();var held=objects.get(index);
                if(!free(body,square)||body.getCell().getGridSquare(square.getX(),square.getY(),z)!=square||held.size()!=square.getObjects().size())return false;
                for(int n=0;n<held.size();n++)if(held.get(n).get()!=square.getObjects().get(n))return false;
            }return true;
        }
    }
    public static synchronized KahluaTable observe(SAOIsoPlayerShell body){
        var out=table();String actor=SAOConceptObservation.actor(body);if(actor==null)return out;
        var eye=body.getCurrentSquare();var sites=SITES.computeIfAbsent(body,b->new LinkedHashMap<>());int count=0;
        for(int radius=0;radius<=8;radius++)for(int dx=-radius;dx<=radius;dx++)for(int dy=-radius;dy<=radius;dy++){
            if(Math.max(Math.abs(dx),Math.abs(dy))!=radius||count>=32)continue;
            var root=body.getCell().getGridSquare(eye.getX()+dx,eye.getY()+dy,eye.getZ());if(!free(body,root))continue;
            for(String face:List.of("S","W")){
                int width=face.equals("S")?3:1,height=face.equals("W")?3:1;boolean valid=true;
                for(int x=0;x<width;x++)for(int y=0;y<height;y++)if(!free(body,body.getCell().getGridSquare(root.getX()+x,root.getY()+y,root.getZ())))valid=false;
                if(!valid)continue;
                int bx=root.getX()+width-1,by=root.getY()+height-1;IsoGridSquare approach=null;double distance=Double.POSITIVE_INFINITY;
                for(int[] side:new int[][]{{1,0},{0,1},{-1,0},{0,-1}}){
                    int x=bx+side[0],y=by+side[1];if(x>=root.getX()&&x<root.getX()+width&&y>=root.getY()&&y<root.getY()+height)continue;
                    var candidate=body.getCell().getGridSquare(x,y,root.getZ());var bottom=body.getCell().getGridSquare(bx,by,root.getZ());
                    if(!free(body,candidate)||candidate.isBlockedTo(bottom)||candidate.isWallTo(bottom)||candidate.isDoorTo(bottom)||candidate.isWindowTo(bottom))continue;
                    double d=Math.hypot(body.getX()-x-.5,body.getY()-y-.5);if(d<distance){approach=candidate;distance=d;}
                }
                if(approach==null)continue;String key="shelter-stair-site:"+root.getX()+":"+root.getY()+":"+root.getZ()+":"+face;
                var site=sites.get(key);if(site==null||!site.current(body,actor)||site.ax!=approach.getX()||site.ay!=approach.getY()){
                    site=new Site(actor,root,approach,face);sites.put(key,site);
                }
                var row=table();row.rawset("key",key);row.rawset("revision",site.revision);row.rawset("face",face);row.rawset("mode","stairs");row.rawset("supported",true);
                put(row,"x",site.x);put(row,"y",site.y);put(row,"z",site.z);put(row,"width",width);put(row,"height",height);
                put(row,"approachX",site.ax);put(row,"approachY",site.ay);put(row,"approachZ",site.z);
                // These coordinates describe the installed recipe's intended effect, not acquired upper geometry.
                put(row,"landingX",site.x-(face.equals("S")?1:0));put(row,"landingY",site.y-(face.equals("W")?1:0));put(row,"landingZ",site.z+1);
                row.rawset("landingObserved",false);row.rawset("landingBasis","native-recipe-effect");out.rawset((double)++count,row);if(count>=32)break;
            }
        }
        while(sites.size()>64)sites.remove(sites.keySet().iterator().next());return out;
    }
    public static synchronized IsoGridSquare placement(SAOIsoPlayerShell body,String key,String revision){
        String actor=SAOConceptObservation.actor(body);var sites=SITES.get(body);var site=sites==null?null:sites.get(key);
        if(actor==null||site==null||!site.revision.equals(revision)||!site.current(body,actor)
            ||body.getCurrentSquare()!=site.squares.get(3).get()||Math.hypot(body.getX()-site.ax-.5,body.getY()-site.ay-.5)>.35)return null;
        return site.squares.get(0).get();
    }
    public static boolean created(SAOIsoPlayerShell body,KahluaTable parts,int x,int y,int z,String face){
        if(SAOConceptObservation.actor(body)==null||parts==null||parts.len()!=3||!Set.of("S","W").contains(face))return false;
        var seen=Collections.newSetFromMap(new IdentityHashMap<IsoObject,Boolean>());
        var types=face.equals("S")?new IsoObjectType[]{IsoObjectType.stairsTW,IsoObjectType.stairsMW,IsoObjectType.stairsBW}
            :new IsoObjectType[]{IsoObjectType.stairsTN,IsoObjectType.stairsMN,IsoObjectType.stairsBN};
        for(int n=0;n<3;n++){
            if(!(parts.rawget((double)n+1) instanceof IsoObject object)||!seen.add(object))return false;
            var square=body.getCell().getGridSquare(x+(face.equals("S")?n:0),y+(face.equals("W")?n:0),z);
            if(square==null||object.getSquare()!=square||object.getObjectIndex()<0||!square.getObjects().contains(object)
                ||object.getType()!=types[n]||object.getEntityScript()==null||!object.getEntityScript().getFullName().equals("Base.Wood_Stairs"))return false;
        }
        var landing=body.getCell().getGridSquare(x-(face.equals("S")?1:0),y-(face.equals("W")?1:0),z+1);
        return landing!=null&&landing.isSolidFloor()&&Boolean.TRUE.equals(landing.getModData().rawget("ConnectedToStairs"+face.equals("W")))
            &&!landing.isSolid()&&!landing.isSolidTrans();
    }
}
