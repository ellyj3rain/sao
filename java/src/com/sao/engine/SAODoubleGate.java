package com.sao.engine;

import java.lang.ref.WeakReference;
import java.util.*;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.objects.IsoDoor;
import zombie.iso.objects.IsoThumpable;

/** Acquired freestanding boundary space and exact native double-door group custody. */
public final class SAODoubleGate {
    private SAODoubleGate() { }
    private static final Set<String> ENTITIES=Set.of("Base.DoubleDoor","Base.DoubleFenceGate","Base.DoubleWireGate");
    private static final Map<SAOIsoPlayerShell,LinkedHashMap<String,Site>> SITES=new WeakHashMap<>();
    private static final Map<SAOIsoPlayerShell,Passage> PASSAGES=new WeakHashMap<>();
    private static KahluaTable table(){return LuaManager.platform.newTable();}
    private static void put(KahluaTable row,String key,int value){row.rawset(key,(double)value);}
    private static boolean visible(SAOIsoPlayerShell body,IsoGridSquare square){return SAOPerceptionScanner.canSeeWorldSquareNow(body,square,8);}
    private static boolean free(SAOIsoPlayerShell body,IsoGridSquare square){
        if(square==null||!square.isSolidFloor()||square.isSolid()||square.isSolidTrans()||!square.isFree(false)
            ||square.HasStairs()||square.HasStairsBelow()||square.haveFire()||square.isVehicleIntersecting())return false;
        for(var moving:square.getMovingObjects())if(moving!=body&&moving.isCharacter())return false;
        return true;
    }
    private static boolean boundary(IsoGridSquare square,boolean north){
        if(square==null)return false;var p=square.getProperties();
        return north?(p.has(IsoFlagType.collideN)||p.has(IsoFlagType.WallN)||p.has(IsoFlagType.HoppableN)||p.has(IsoFlagType.TallHoppableN))
            :(p.has(IsoFlagType.collideW)||p.has(IsoFlagType.WallW)||p.has(IsoFlagType.HoppableW)||p.has(IsoFlagType.TallHoppableW));
    }
    private static final class Site {
        final String actor,key,revision=UUID.randomUUID().toString(),face;
        final int x,y,z,width,height;
        final ArrayList<WeakReference<IsoGridSquare>> squares=new ArrayList<>();
        final ArrayList<ArrayList<WeakReference<IsoObject>>> objects=new ArrayList<>();
        Site(String actor,IsoGridSquare root,String face){
            this.actor=actor;this.face=face;x=root.getX();y=root.getY();z=root.getZ();width=face.equals("N")?4:1;height=face.equals("W")?4:1;
            key="double-gate-site:"+x+":"+y+":"+z+":"+face;
            for(int dx=face.equals("W")?-1:0;dx<=(face.equals("N")?3:1);dx++)
                for(int dy=face.equals("N")?-1:0;dy<=(face.equals("W")?3:1);dy++)capture(root.getCell().getGridSquare(x+dx,y+dy,z));
            capture(root.getCell().getGridSquare(x-(face.equals("N")?1:0),y-(face.equals("W")?1:0),z));
            capture(root.getCell().getGridSquare(x+(face.equals("N")?4:0),y+(face.equals("W")?4:0),z));
        }
        void capture(IsoGridSquare square){
            squares.add(new WeakReference<>(square));var held=new ArrayList<WeakReference<IsoObject>>();
            for(int n=0;n<square.getObjects().size();n++)held.add(new WeakReference<>(square.getObjects().get(n)));objects.add(held);
        }
        boolean current(SAOIsoPlayerShell body,String actor){
            if(!this.actor.equals(actor)||Math.floor(body.getZ())!=z)return false;
            for(int n=0;n<squares.size();n++){
                var square=squares.get(n).get();if(square==null||body.getCell().getGridSquare(square.getX(),square.getY(),z)!=square)return false;
                if(n<squares.size()-2&&!free(body,square))return false;var held=objects.get(n);
                if(held.size()!=square.getObjects().size())return false;
                for(int i=0;i<held.size();i++)if(held.get(i).get()!=square.getObjects().get(i))return false;
            }
            return boundary(squares.get(squares.size()-2).get(),face.equals("N"))&&boundary(squares.get(squares.size()-1).get(),face.equals("N"));
        }
    }
    public static synchronized KahluaTable observe(SAOIsoPlayerShell body){
        var out=table();String actor=SAOConceptObservation.actor(body);if(actor==null)return out;var eye=body.getCurrentSquare();int count=0;
        var sites=SITES.computeIfAbsent(body,b->new LinkedHashMap<>());
        for(int radius=0;radius<=6;radius++)for(int dx=-radius;dx<=radius;dx++)for(int dy=-radius;dy<=radius;dy++){
            if(Math.max(Math.abs(dx),Math.abs(dy))!=radius||count>=16)continue;
            var root=body.getCell().getGridSquare(eye.getX()+dx,eye.getY()+dy,eye.getZ());if(!free(body,root))continue;
            for(String face:List.of("N","W")){
                boolean north=face.equals("N");var first=body.getCell().getGridSquare(root.getX()-(north?1:0),root.getY()-(north?0:1),root.getZ());
                var last=body.getCell().getGridSquare(root.getX()+(north?4:0),root.getY()+(north?0:4),root.getZ());
                if(!visible(body,first)||!visible(body,last)||!boundary(first,north)||!boundary(last,north))continue;
                boolean clear=true;
                for(int x=north?0:-1;x<=(north?3:1);x++)for(int y=north?-1:0;y<=(north?1:3);y++)
                    if(!free(body,body.getCell().getGridSquare(root.getX()+x,root.getY()+y,root.getZ()))||!visible(body,body.getCell().getGridSquare(root.getX()+x,root.getY()+y,root.getZ())))clear=false;
                for(int n=0;n<4;n++)if(boundary(body.getCell().getGridSquare(root.getX()+(north?n:0),root.getY()+(north?0:n),root.getZ()),north))clear=false;
                if(!clear)continue;String key="double-gate-site:"+root.getX()+":"+root.getY()+":"+root.getZ()+":"+face;
                var site=sites.get(key);if(site==null||!site.current(body,actor)){site=new Site(actor,root,face);sites.put(key,site);}
                var row=table();row.rawset("key",key);row.rawset("revision",site.revision);row.rawset("face",face);row.rawset("boundaryObserved",true);
                put(row,"x",site.x);put(row,"y",site.y);put(row,"z",site.z);put(row,"width",site.width);put(row,"height",site.height);
                put(row,"approachX",site.x+(north?1:1));put(row,"approachY",site.y+(north?1:1));put(row,"approachZ",site.z);
                put(row,"destinationX",site.x+(north?1:-1));put(row,"destinationY",site.y+(north?-1:1));put(row,"destinationZ",site.z);
                out.rawset((double)++count,row);
            }
        }
        while(sites.size()>64)sites.remove(sites.keySet().iterator().next());return out;
    }
    public static synchronized IsoGridSquare placement(SAOIsoPlayerShell body,String key,String revision){
        String actor=SAOConceptObservation.actor(body);var sites=SITES.get(body);var site=sites==null?null:sites.get(key);
        return actor!=null&&site!=null&&site.revision.equals(revision)&&site.current(body,actor)
            &&body.getCurrentSquare()==body.getCell().getGridSquare(site.x+1,site.y+1,site.z)
            &&Math.hypot(body.getX()-site.x-1.5,body.getY()-site.y-1.5)<=.35?body.getCell().getGridSquare(site.x,site.y,site.z):null;
    }
    public static String created(SAOIsoPlayerShell body,KahluaTable parts,String entity,int x,int y,int z,String face){
        if(SAOConceptObservation.actor(body)==null||!ENTITIES.contains(entity)||parts==null||parts.len()!=4||!Set.of("N","W").contains(face))return null;
        var seen=Collections.newSetFromMap(new IdentityHashMap<IsoObject,Boolean>());
        for(int n=0;n<4;n++){
            if(!(parts.rawget((double)n+1) instanceof IsoThumpable object)||!seen.add(object)||!object.isDoor()||object.IsOpen()
                ||object.getSquare()!=body.getCell().getGridSquare(x+(face.equals("N")?n:0),y+(face.equals("W")?n:0),z)
                ||object.getObjectIndex()<0||IsoDoor.getDoubleDoorIndex(object)!=(face.equals("N")?n+1:4-n)
                ||object.getEntityScript()==null||!object.getEntityScript().getFullName().equals(entity))return null;
        }
        String id=UUID.randomUUID().toString();for(int n=0;n<4;n++){
            var object=(IsoThumpable)parts.rawget((double)n+1);object.getModData().rawset("SAODoubleGateId",id);
            object.getModData().rawset("SAODoubleGateMember",(double)(face.equals("N")?n+1:4-n));object.getModData().rawset("SAODoubleGateEntity",entity);
        }return id;
    }
    private static ArrayList<IsoThumpable> members(SAOIsoPlayerShell body,String id,String entity,int x,int y,int z,String face){
        if(SAOConceptObservation.actor(body)==null||id==null||!ENTITIES.contains(entity)||!Set.of("N","W").contains(face))return null;
        var root=body.getCell().getGridSquare(x,y,z);if(root==null)return null;IsoThumpable anchor=null;
        for(int n=0;n<root.getObjects().size();n++)if(root.getObjects().get(n) instanceof IsoThumpable object
            &&id.equals(object.getModData().rawget("SAODoubleGateId"))&&IsoDoor.getDoubleDoorIndex(object)==(face.equals("N")?1:4))anchor=object;
        if(anchor==null||anchor.getNorth()!=face.equals("N"))return null;
        var out=new ArrayList<IsoThumpable>();var seen=Collections.newSetFromMap(new IdentityHashMap<IsoObject,Boolean>());
        for(int n=1;n<=4;n++){
            if(!(IsoDoor.getDoubleDoorObject(anchor,n) instanceof IsoThumpable object)||!seen.add(object)||!object.isDoor()||object.isDestroyed()
                ||object.getObjectIndex()<0||object.getSquare().getCell()!=body.getCell()||!id.equals(object.getModData().rawget("SAODoubleGateId"))
                ||!entity.equals(object.getModData().rawget("SAODoubleGateEntity"))||!Double.valueOf(n).equals(object.getModData().rawget("SAODoubleGateMember"))
                ||object.IsOpen()!=anchor.IsOpen())return null;
            var square=object.getSquare();for(int k=0;k<square.getObjects().size();k++){
                var other=square.getObjects().get(k);if(other!=object&&other instanceof IsoThumpable competitor&&competitor.isDoor()
                    &&competitor.getNorth()==anchor.getNorth()&&IsoDoor.getDoubleDoorIndex(competitor)==n)return null;
            }out.add(object);
        }return out;
    }
    public static KahluaTable group(SAOIsoPlayerShell body,String id,String entity,int x,int y,int z,String face){
        var members=members(body,id,entity,x,y,z,face);if(members==null)return null;var row=table();row.rawset("id",id);row.rawset("entityId",entity);
        row.rawset("open",members.get(0).IsOpen());row.rawset("observed",visible(body,members.get(face.equals("N")?0:3).getSquare()));var parts=table();boolean relocated=false;
        for(int n=0;n<4;n++){var object=members.get(n);var part=table();put(part,"x",object.getSquare().getX());put(part,"y",object.getSquare().getY());put(part,"z",object.getSquare().getZ());put(part,"member",n+1);
            relocated|=object.getX()!=x+(face.equals("N")?n:0)||object.getY()!=y+(face.equals("W")?3-n:0);parts.rawset((double)n+1,part);}
        row.rawset("parts",parts);row.rawset("relocated",relocated);return row;
    }
    public static IsoThumpable leaf(SAOIsoPlayerShell body,String id,String entity,int x,int y,int z,String face){
        var members=members(body,id,entity,x,y,z,face);return members==null?null:members.get(0);
    }
    private static final class Passage {
        final String id,entity,face,actor,token=UUID.randomUUID().toString();final int x,y,z,tx,ty,fx,fy;boolean crossed;
        Passage(SAOIsoPlayerShell body,String id,String entity,int x,int y,int z,String face,int fx,int fy,int tx,int ty){this.actor=SAOConceptObservation.actor(body);this.id=id;this.entity=entity;this.x=x;this.y=y;this.z=z;this.face=face;this.fx=fx;this.fy=fy;this.tx=tx;this.ty=ty;}
    }
    public static synchronized String beginPassage(SAOIsoPlayerShell body,String id,String entity,int x,int y,int z,String face,int tx,int ty){
        var group=members(body,id,entity,x,y,z,face);var from=body.getCurrentSquare();var to=body.getCell().getGridSquare(tx,ty,z);
        if(group==null||!group.get(0).IsOpen()||!free(body,to)||from==null||from.getZ()!=z
            ||face.equals("N")&&(from.getX()!=x+1||from.getY()!=y+1||tx!=x+1||ty!=y-1)
            ||face.equals("W")&&(from.getX()!=x+1||from.getY()!=y+1||tx!=x-1||ty!=y+1))return null;
        var p=new Passage(body,id,entity,x,y,z,face,from.getX(),from.getY(),tx,ty);PASSAGES.put(body,p);return p.token;
    }
    public static synchronized void observePassage(SAOIsoPlayerShell body){
        var p=PASSAGES.get(body);if(p==null)return;
        if(!p.actor.equals(SAOConceptObservation.actor(body))){PASSAGES.remove(body);return;}
        var group=members(body,p.id,p.entity,p.x,p.y,p.z,p.face);
        var current=body.getCurrentSquare();var last=body.getLastSquare();
        if(group==null||!group.get(0).IsOpen()||current==null||last==null)return;
        boolean north=p.face.equals("N");
        if(last.getZ()==p.z&&current.getZ()==p.z&&last.getX()==(north?p.x+1:p.x)&&last.getY()==(north?p.y:p.y+1)
            &&current.getX()==(north?p.x+1:p.x-1)&&current.getY()==(north?p.y-1:p.y+1))p.crossed=true;
    }
    public static synchronized boolean passage(SAOIsoPlayerShell body,String token){
        var p=PASSAGES.get(body);var current=body.getCurrentSquare();
        return p!=null&&p.token.equals(token)&&p.actor.equals(SAOConceptObservation.actor(body))&&p.crossed
            &&members(body,p.id,p.entity,p.x,p.y,p.z,p.face)!=null&&current!=null&&current.getX()==p.tx&&current.getY()==p.ty&&current.getZ()==p.z;
    }
    public static synchronized void forgetPassage(SAOIsoPlayerShell body,String token){var p=PASSAGES.get(body);if(p!=null&&p.token.equals(token))PASSAGES.remove(body);}
}
