package com.sao.engine;

import java.lang.ref.WeakReference;
import java.util.*;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.iso.*;
import zombie.iso.objects.*;
import zombie.iso.SpriteDetails.IsoFlagType;

/** Personally observed one-edge boundary gaps and same-body single-leaf passage. */
public final class SAOEnclosureEdge {
    private SAOEnclosureEdge() { }
    private static final Set<String> GATES=Set.of("Base.MetalPoleFenceGate","Base.MetalPoleFenceGateSmall","Base.MetalWireFenceGate","Base.MetalWireFenceGateSmall");
    private static final Map<SAOIsoPlayerShell,LinkedHashMap<String,Site>> SITES=new WeakHashMap<>();
    private static final Map<SAOIsoPlayerShell,Passage> PASSAGES=new WeakHashMap<>();
    private static KahluaTable table(){return LuaManager.platform.newTable();}
    private static void put(KahluaTable t,String k,int n){t.rawset(k,(double)n);}
    private static boolean visible(SAOIsoPlayerShell b,IsoGridSquare q){return SAOPerceptionScanner.canSeeWorldSquareNow(b,q,8);}
    private static boolean free(SAOIsoPlayerShell b,IsoGridSquare q){
        if(q==null||!q.isSolidFloor()||q.isSolid()||q.isSolidTrans()||!q.isFree(false)||q.HasStairs()||q.HasStairsBelow()||q.haveFire()||q.isVehicleIntersecting())return false;
        for(var m:q.getMovingObjects())if(m!=b&&m.isCharacter())return false;
        return true;
    }
    private static boolean boundary(IsoGridSquare q,boolean north){
        if(q==null)return false;var p=q.getProperties();
        return p.has(north?IsoFlagType.collideN:IsoFlagType.collideW)||p.has(north?IsoFlagType.HoppableN:IsoFlagType.HoppableW)
            ||p.has(north?IsoFlagType.TallHoppableN:IsoFlagType.TallHoppableW)||p.has(north?IsoFlagType.WallN:IsoFlagType.WallW);
    }
    private static final class Site {
        final String actor,key,revision=UUID.randomUUID().toString(),face;
        final int x,y,z;
        final WeakReference<IsoCell> cell;
        final List<WeakReference<IsoGridSquare>> squares=new ArrayList<>();
        final List<List<WeakReference<IsoObject>>> objects=new ArrayList<>();
        Site(String actor,IsoGridSquare q,boolean north){
            this.actor=actor;face=north?"N":"W";x=q.getX();y=q.getY();z=q.getZ();cell=new WeakReference<>(q.getCell());
            key="boundary-edge:"+x+":"+y+":"+z+":"+face;
            capture(q);capture(q.getCell().getGridSquare(x-(north?0:1),y-(north?1:0),z));
            capture(q.getCell().getGridSquare(x-(north?1:0),y-(north?0:1),z));
            capture(q.getCell().getGridSquare(x+(north?1:0),y+(north?0:1),z));
        }
        void capture(IsoGridSquare q){squares.add(new WeakReference<>(q));var held=new ArrayList<WeakReference<IsoObject>>();for(int n=0;n<q.getObjects().size();n++)held.add(new WeakReference<>(q.getObjects().get(n)));objects.add(held);}
        boolean current(SAOIsoPlayerShell b){
            if(!actor.equals(SAOConceptObservation.actor(b))||cell.get()!=b.getCell()||Math.floor(b.getZ())!=z)return false;
            for(int n=0;n<squares.size();n++){
                var q=squares.get(n).get();if(q==null||b.getCell().getGridSquare(q.getX(),q.getY(),q.getZ())!=q||!visible(b,q)||n<2&&!free(b,q))return false;
                var held=objects.get(n);if(held.size()!=q.getObjects().size())return false;
                for(int k=0;k<held.size();k++)if(held.get(k).get()!=q.getObjects().get(k))return false;
            }
            return !boundary(squares.get(0).get(),face.equals("N"))&&boundary(squares.get(2).get(),face.equals("N"))&&boundary(squares.get(3).get(),face.equals("N"));
        }
    }
    public static synchronized KahluaTable observe(SAOIsoPlayerShell b){
        var out=table();String actor=SAOConceptObservation.actor(b);var eye=b.getCurrentSquare();if(actor==null||eye==null)return out;
        var sites=SITES.computeIfAbsent(b,v->new LinkedHashMap<>());int count=0;
        for(int r=0;r<=6;r++)for(int dx=-r;dx<=r;dx++)for(int dy=-r;dy<=r;dy++){
            if(Math.max(Math.abs(dx),Math.abs(dy))!=r||count>=16)continue;
            var q=b.getCell().getGridSquare(eye.getX()+dx,eye.getY()+dy,eye.getZ());if(!visible(b,q)||!free(b,q))continue;
            for(boolean north:new boolean[]{true,false}){
                var op=b.getCell().getGridSquare(q.getX()-(north?0:1),q.getY()-(north?1:0),q.getZ());
                var first=b.getCell().getGridSquare(q.getX()-(north?1:0),q.getY()-(north?0:1),q.getZ());
                var last=b.getCell().getGridSquare(q.getX()+(north?1:0),q.getY()+(north?0:1),q.getZ());
                if(!free(b,op)||!visible(b,op)||!visible(b,first)||!visible(b,last)||boundary(q,north)||!boundary(first,north)||!boundary(last,north))continue;
                String key="boundary-edge:"+q.getX()+":"+q.getY()+":"+q.getZ()+":"+(north?"N":"W");
                var site=sites.get(key);if(site==null||!site.current(b)){site=new Site(actor,q,north);sites.put(key,site);}
                var row=table();row.rawset("key",key);row.rawset("revision",site.revision);row.rawset("face",site.face);row.rawset("mode","boundary");row.rawset("boundaryObserved",true);
                put(row,"x",site.x);put(row,"y",site.y);put(row,"z",site.z);put(row,"width",1);put(row,"height",1);
                put(row,"approachX",site.x);put(row,"approachY",site.y);put(row,"approachZ",site.z);
                put(row,"destinationX",site.x-(north?0:1));put(row,"destinationY",site.y-(north?1:0));put(row,"destinationZ",site.z);
                out.rawset((double)++count,row);
            }
        }
        while(sites.size()>64)sites.remove(sites.keySet().iterator().next());return out;
    }
    public static synchronized IsoGridSquare placement(SAOIsoPlayerShell b,String key,String revision){
        var sites=SITES.get(b);var s=sites==null?null:sites.get(key);
        return s!=null&&s.revision.equals(revision)&&s.current(b)&&b.getCurrentSquare()==s.squares.get(0).get()
            &&Math.hypot(b.getX()-s.x-.5,b.getY()-s.y-.5)<=.35?s.squares.get(0).get():null;
    }
    public static String created(SAOIsoPlayerShell b,IsoThumpable o,String entity,int x,int y,int z,String face){
        if(SAOConceptObservation.actor(b)==null||o==null||o.getSquare()!=b.getCell().getGridSquare(x,y,z)||o.getObjectIndex()<0
            ||!visible(b,o.getSquare())||o.isDestroyed()||o.getEntityScript()==null||!entity.equals(o.getEntityScript().getFullName())
            ||!Set.of("N","W").contains(face)||o.getNorth()!=face.equals("N"))return null;
        if(GATES.contains(entity)){
            if(!o.isDoor()||o.IsOpen()||IsoDoor.getDoubleDoorIndex(o)!=-1)return null;
            String id=UUID.randomUUID().toString();o.getModData().rawset("SAOBoundaryLeafId",id);return id;
        }
        return entity.startsWith("Base.Metal")&&entity.contains("Fence")&&boundary(o.getSquare(),face.equals("N"))?"measured-boundary":null;
    }
    public static IsoThumpable leaf(SAOIsoPlayerShell b,String id,String entity,int x,int y,int z,String face){
        if(SAOConceptObservation.actor(b)==null||id==null||!GATES.contains(entity)||!Set.of("N","W").contains(face))return null;
        var q=b.getCell().getGridSquare(x,y,z);if(q==null)return null;IsoThumpable found=null;
        for(int n=0;n<q.getObjects().size();n++)if(q.getObjects().get(n) instanceof IsoThumpable o&&id.equals(o.getModData().rawget("SAOBoundaryLeafId"))
            &&o.isDoor()&&!o.isDestroyed()&&o.getObjectIndex()>=0&&o.getNorth()==face.equals("N")
            &&o.getEntityScript()!=null&&entity.equals(o.getEntityScript().getFullName())){if(found!=null)return null;found=o;}
        return found;
    }
    public static KahluaTable state(SAOIsoPlayerShell b,String id,String entity,int x,int y,int z,String face){
        var o=leaf(b,id,entity,x,y,z,face);if(o==null)return null;var row=table();row.rawset("id",id);row.rawset("entityId",entity);row.rawset("open",o.IsOpen());row.rawset("observed",visible(b,o.getSquare()));row.rawset("relocated",false);
        var parts=table();var part=table();put(part,"x",x);put(part,"y",y);put(part,"z",z);put(part,"member",1);parts.rawset(1.0,part);row.rawset("parts",parts);return row;
    }
    private static final class Passage {
        final String actor,token=UUID.randomUUID().toString();final WeakReference<IsoCell> cell;final WeakReference<IsoThumpable> leaf;final WeakReference<IsoGridSquare> from,to;boolean crossed;
        Passage(SAOIsoPlayerShell b,IsoThumpable o,IsoGridSquare from,IsoGridSquare to){actor=SAOConceptObservation.actor(b);cell=new WeakReference<>(b.getCell());leaf=new WeakReference<>(o);this.from=new WeakReference<>(from);this.to=new WeakReference<>(to);}
    }
    public static synchronized String beginPassage(SAOIsoPlayerShell b,String id,String entity,int x,int y,int z,String face,int tx,int ty){
        var o=leaf(b,id,entity,x,y,z,face);var from=b.getCurrentSquare();var to=b.getCell().getGridSquare(tx,ty,z);
        if(o==null||!o.IsOpen()||from!=o.getSquare()||!free(b,to)||!visible(b,to)||tx!=x-(face.equals("W")?1:0)||ty!=y-(face.equals("N")?1:0))return null;
        var p=new Passage(b,o,from,to);PASSAGES.put(b,p);return p.token;
    }
    public static synchronized void observePassage(SAOIsoPlayerShell b){
        var p=PASSAGES.get(b);if(p==null)return;var o=p.leaf.get();
        if(!p.actor.equals(SAOConceptObservation.actor(b))||p.cell.get()!=b.getCell()||o==null||o.getObjectIndex()<0||o.isDestroyed()){PASSAGES.remove(b);return;}
        if(b.getLastSquare()==p.from.get()&&b.getCurrentSquare()==p.to.get()&&o.IsOpen()&&o.getSquare()==p.from.get())p.crossed=true;
    }
    public static synchronized boolean passage(SAOIsoPlayerShell b,String token){var p=PASSAGES.get(b);return p!=null&&p.token.equals(token)&&p.actor.equals(SAOConceptObservation.actor(b))&&p.cell.get()==b.getCell()&&p.crossed;}
    public static synchronized void forgetPassage(SAOIsoPlayerShell b,String token){var p=PASSAGES.get(b);if(p!=null&&p.token.equals(token))PASSAGES.remove(b);}
}
