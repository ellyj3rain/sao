package com.sao.engine;

import java.util.*;
import java.lang.ref.WeakReference;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.objects.IsoThumpable;
import zombie.iso.objects.IsoDoor;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.SpriteDetails.IsoObjectType;

/** Personally visible existing roof-space edges. Engine construction and entry own mutations. */
public final class SAOShelterConstruction {
    private SAOShelterConstruction() { }
    private static final Map<SAOIsoPlayerShell,LinkedHashMap<String,Site>> SITES=new WeakHashMap<>();
    private static final int[][] SIDES={{-1,0},{1,0},{0,-1},{0,1}};
    private static boolean visible(SAOIsoPlayerShell body,IsoGridSquare square) {
        return SAOPerceptionScanner.canSeeWorldSquareNow(body,square,8);
    }
    private static boolean free(SAOIsoPlayerShell body,IsoGridSquare square) {
        if(square==null||!square.isSolidFloor()||square.isSolid()||square.isSolidTrans()
            ||!square.isFree(false)||square.HasTree()||square.HasStairs()||square.HasStairsBelow()
            ||square.haveFire()||square.isVehicleIntersecting())return false;
        for(int i=0;i<square.getObjects().size();i++)if(square.getObjects().get(i) instanceof IsoThumpable object
            &&object.isBlockAllTheSquare())return false;
        for(var moving:square.getMovingObjects())if(moving!=body&&moving.isCharacter())return false;
        return true;
    }
    private static String entity(IsoObject object) {
        return object==null||object.getEntityScript()==null?"":object.getEntityScript().getFullName();
    }
    private static boolean facing(IsoObject object,boolean north) {
        if(object instanceof IsoDoor door)return door.getNorth()==north;
        if(object instanceof IsoThumpable thump)return thump.getNorth()==north;
        var type=object.getType();
        return north?(type==IsoObjectType.doorFrN||type==IsoObjectType.doorN)
            :(type==IsoObjectType.doorFrW||type==IsoObjectType.doorW);
    }
    private static IsoObject edge(IsoGridSquare square,boolean north) {
        IsoObject frame=null;
        for(int i=0;i<square.getObjects().size();i++){
            var o=square.getObjects().get(i);if(!facing(o,north))continue;
            if(o instanceof IsoDoor)return o;
            if(o instanceof IsoThumpable thump&&thump.isDoor())return o;
            String id=entity(o);
            if(id.contains("Wall")||id.contains("DoorFrame")||o.getType()==(north?IsoObjectType.doorFrN:IsoObjectType.doorFrW))frame=o;
        }
        return frame;
    }
    private static IsoGridSquare other(IsoGridSquare sq,boolean north){
        return sq.getCell().getGridSquare(sq.getX()-(north?0:1),sq.getY()-(north?1:0),sq.getZ());
    }
    private static String mode(IsoGridSquare sq,boolean north,IsoObject object){
        if(object instanceof IsoDoor)return "door";
        if(object instanceof IsoThumpable t&&t.isDoor()&&!t.isDestroyed())return "door";
        String id=entity(object);
        if(id.equals("Base.WoodenWallFrame")||id.equals("Base.MetalWallFrame"))return "wall";
        if(id.startsWith("Base.WoodDoorFrame")||object!=null&&object.getType()==(north?IsoObjectType.doorFrN:IsoObjectType.doorFrW))return "door-leaf";
        var p=sq.getProperties();
        if(p!=null&&(p.has(north?IsoFlagType.WallN:IsoFlagType.WallW)
            ||p.has(north?IsoFlagType.WallNTrans:IsoFlagType.WallWTrans)
            ||p.has(north?IsoFlagType.WindowN:IsoFlagType.WindowW)))return "sealed";
        return "empty";
    }
    private static final class Site {
        final String actor,key,revision=UUID.randomUUID().toString(),mode;
        final WeakReference<IsoGridSquare> square,opposite,approach,inside;
        final WeakReference<IsoObject> previous;
        final int x,y,z,ax,ay,ix,iy,originX,originY;
        final boolean north;
        final ArrayList<WeakReference<IsoObject>> objects=new ArrayList<>();
        Site(String actor,String key,IsoGridSquare square,IsoGridSquare opposite,IsoGridSquare approach,
             IsoGridSquare inside,boolean north,String mode,IsoObject previous,int ox,int oy){
            this.actor=actor;this.key=key;this.square=new WeakReference<>(square);this.opposite=new WeakReference<>(opposite);
            this.approach=new WeakReference<>(approach);this.inside=new WeakReference<>(inside);this.previous=new WeakReference<>(previous);
            this.north=north;this.mode=mode;x=square.getX();y=square.getY();z=square.getZ();
            ax=approach.getX();ay=approach.getY();ix=inside.getX();iy=inside.getY();originX=ox;originY=oy;
            for(int i=0;i<square.getObjects().size();i++)objects.add(new WeakReference<>(square.getObjects().get(i)));
        }
        boolean current(SAOIsoPlayerShell body,String actor){
            var sq=body.getCell().getGridSquare(x,y,z);var op=other(sq,north);
            if(!this.actor.equals(actor)||square.get()!=sq||opposite.get()!=op||inside.get()==null||!inside.get().haveRoof
                ||(!visible(body,sq)&&!visible(body,op))||!free(body,approach.get())||!visible(body,approach.get())
                ||objects.size()!=sq.getObjects().size()||previous.get()!=edge(sq,north)||!mode.equals(mode(sq,north,previous.get())))return false;
            for(int i=0;i<objects.size();i++)if(objects.get(i).get()!=sq.getObjects().get(i))return false;
            return true;
        }
    }
    private static KahluaTable table(){return LuaManager.platform.newTable();}
    private static void put(KahluaTable t,String key,int value){t.rawset(key,(double)value);}
    public static synchronized KahluaTable observe(SAOIsoPlayerShell body,int ox,int oy,int z){
        var out=table();String actor=SAOConceptObservation.actor(body);
        if(actor==null||body.getCurrentSquare()==null||Math.floor(body.getZ())!=z)return out;
        var origin=body.getCell().getGridSquare(ox,oy,z);
        if(!visible(body,origin)||!origin.haveRoof||!free(body,origin))return out;
        var roof=new LinkedHashSet<IsoGridSquare>();var queue=new ArrayDeque<IsoGridSquare>();queue.add(origin);
        while(!queue.isEmpty()){
            var sq=queue.remove();if(roof.contains(sq))continue;
            if(!visible(body,sq)||!sq.haveRoof||!free(body,sq))continue;
            if(roof.size()>=64)break;roof.add(sq);
            for(int[] side:SIDES){
                var neighbor=body.getCell().getGridSquare(sq.getX()+side[0],sq.getY()+side[1],z);
                if(neighbor!=null&&visible(body,neighbor)&&neighbor.haveRoof&&!sq.isWallTo(neighbor)
                    &&!sq.isWindowTo(neighbor)&&!sq.isBlockedTo(neighbor))queue.add(neighbor);
            }
        }
        var sites=SITES.computeIfAbsent(body,ignored->new LinkedHashMap<>());
        var boundaries=new LinkedHashMap<String,IsoGridSquare[]>();
        boolean hasDoor=false;
        for(var inside:roof)for(int[] side:SIDES){
            var neighbor=body.getCell().getGridSquare(inside.getX()+side[0],inside.getY()+side[1],z);
            if(neighbor==null)return table();
            boolean north=side[1]!=0;
            var sq=side[0]>0||side[1]>0?neighbor:inside;
            boolean ownsVisibleEdge=visible(body,sq),neighborVisible=visible(body,neighbor);
            var occupied=ownsVisibleEdge?edge(sq,north):null;
            String occupiedMode=ownsVisibleEdge?mode(sq,north,occupied):"";
            if(occupiedMode.equals("door")||occupiedMode.equals("door-leaf"))hasDoor=true;
            boolean visibleDoor=ownsVisibleEdge&&usableDoor(occupied);
            // Observed doors can be opened before seeing through them; construction needs the far square.
            if(!neighborVisible&&!visibleDoor)continue;
            if(roof.contains(neighbor))continue;
            // A same-roof tile excluded by an interior wall is not a new exterior breach.
            if(neighborVisible&&neighbor.haveRoof)continue;
            var op=other(sq,north);
            String key="shelter-edge:"+ox+":"+oy+":"+z+":"+sq.getX()+":"+sq.getY()+":"+(north?"N":"W");
            boundaries.put(key,new IsoGridSquare[]{sq,op,inside});
        }
        int count=0;boolean proposedDoor=hasDoor;
        for(var entry:boundaries.entrySet()){
            if(count>=32)break;
            var sq=entry.getValue()[0];var op=entry.getValue()[1];var inside=entry.getValue()[2];
            boolean north=sq.getY()!=op.getY();
            var approach=free(body,inside)?inside:free(body,sq)?sq:free(body,op)?op:null;
            if(approach==null)continue;
            var object=edge(sq,north);String mode=mode(sq,north,object);
            if(mode.equals("sealed"))continue;
            if(mode.equals("empty")){mode=proposedDoor?"wall-frame":"door-frame";if(!proposedDoor)proposedDoor=true;}
            var site=sites.get(entry.getKey());
            String actualMode=mode(sq,north,object);
            if(site==null||!site.current(body,actor)||site.ax!=approach.getX()||site.ay!=approach.getY()){
                site=new Site(actor,entry.getKey(),sq,op,approach,inside,north,actualMode,object,ox,oy);sites.put(site.key,site);
            }
            var row=table();row.rawset("key",site.key);row.rawset("revision",site.revision);row.rawset("face",north?"N":"W");
            row.rawset("mode",mode);row.rawset("previousEntity",entity(object));
            put(row,"x",site.x);put(row,"y",site.y);put(row,"z",site.z);put(row,"approachX",site.ax);put(row,"approachY",site.ay);
            put(row,"approachZ",site.z);put(row,"insideX",site.ix);put(row,"insideY",site.iy);put(row,"originX",ox);put(row,"originY",oy);
            row.rawset("roof",true);out.rawset((double)++count,row);
        }
        // A newly covered, visibly continuous interior retires its exact former cover boundary.
        for(var site:sites.values()){
            if(count>=32||site.originX!=ox||site.originY!=oy||site.z!=z||boundaries.containsKey(site.key))continue;
            var square=site.square.get();var opposite=site.opposite.get();
            if(square==null||opposite==null||!visible(body,square)||!visible(body,opposite)||!square.haveRoof||!opposite.haveRoof
                ||!mode(square,site.north,edge(square,site.north)).equals("empty")||square.isBlockedTo(opposite)
                ||square.getRoom()!=opposite.getRoom())continue;
            var row=table();row.rawset("key",site.key);row.rawset("revision",site.revision);row.rawset("face",site.north?"N":"W");
            row.rawset("mode","covered-interior");row.rawset("previousEntity","");row.rawset("roof",true);
            put(row,"x",site.x);put(row,"y",site.y);put(row,"z",site.z);put(row,"approachX",site.ax);put(row,"approachY",site.ay);
            put(row,"approachZ",site.z);put(row,"insideX",site.ix);put(row,"insideY",site.iy);put(row,"originX",ox);put(row,"originY",oy);
            out.rawset((double)++count,row);
        }
        while(sites.size()>128)sites.remove(sites.keySet().iterator().next());return out;
    }
    private static Site known(SAOIsoPlayerShell body,String key,String revision){
        String actor=SAOConceptObservation.actor(body);var sites=SITES.get(body);var site=sites==null?null:sites.get(key);
        return actor!=null&&site!=null&&site.revision.equals(revision)&&site.current(body,actor)?site:null;
    }
    public static synchronized IsoGridSquare placement(SAOIsoPlayerShell body,String key,String revision){
        var s=known(body,key,revision);
        return s!=null&&Math.hypot(body.getX()-s.ax-.5,body.getY()-s.ay-.5)<=.35
            &&Math.abs(body.getZ()-s.z)<.1?s.square.get():null;
    }
    public static synchronized IsoObject previous(SAOIsoPlayerShell body,String key,String revision){
        var s=known(body,key,revision);return s==null?null:s.previous.get();
    }
    public static boolean created(SAOIsoPlayerShell body,IsoThumpable object,IsoObject previous,
                                  String entityId,int x,int y,int z,String face){
        var sq=body.getCell().getGridSquare(x,y,z);
        return SAOConceptObservation.actor(body)!=null&&object!=null&&object!=previous&&object.getSquare()==sq
            &&object.getCell()==body.getCell()&&object.getObjectIndex()>=0&&sq.getObjects().contains(object)
            &&visible(body,sq)&&entity(object).equals(entityId)&&object.getNorth()==face.equals("N")
            &&(previous==null||!sq.getObjects().contains(previous))&&object.getHealth()>0;
    }
    public static synchronized IsoObject door(SAOIsoPlayerShell body,String key,String revision){
        var s=known(body,key,revision);var object=s==null?null:s.previous.get();
        return object instanceof IsoDoor d&&!d.isDestroyed()?d:object instanceof IsoThumpable t&&t.isDoor()&&!t.isDestroyed()?t:null;
    }
    private static boolean usableDoor(IsoObject door){
        return door instanceof IsoDoor d&&!d.isDestroyed()||door instanceof IsoThumpable t&&t.isDoor()&&!t.isDestroyed();
    }
    private static boolean open(IsoObject door){
        return door instanceof IsoDoor d?d.IsOpen():door instanceof IsoThumpable t&&t.IsOpen();
    }
    private static final Map<SAOIsoPlayerShell,Passage> PASSAGES=new WeakHashMap<>();
    private static final class Passage {
        final String actor,token=UUID.randomUUID().toString();
        final WeakReference<IsoObject> door;
        final WeakReference<IsoGridSquare> from,to;
        final WeakReference<zombie.iso.IsoCell> cell;
        WeakReference<IsoGridSquare> last;
        boolean matched;
        Passage(String actor,SAOIsoPlayerShell body,IsoObject door,IsoGridSquare from,IsoGridSquare to){
            this.actor=actor;this.door=new WeakReference<>(door);this.from=new WeakReference<>(from);this.to=new WeakReference<>(to);
            cell=new WeakReference<>(body.getCell());last=new WeakReference<>(body.getCurrentSquare());
        }
    }
    public static synchronized String beginPassage(SAOIsoPlayerShell body,IsoObject door,String key,String revision,boolean inward){
        var s=known(body,key,revision);
        if(s==null||s.previous.get()!=door||!usableDoor(door)||!open(door))return null;
        var inside=s.inside.get();var outside=s.square.get()==inside?s.opposite.get():s.square.get();
        var from=inward?outside:inside;var to=inward?inside:outside;
        if(body.getCurrentSquare()!=from||from==null||to==null||!visible(body,outside)
            ||!free(body,from)||!free(body,to))return null;
        var p=new Passage(s.actor,body,door,from,to);PASSAGES.put(body,p);return p.token;
    }
    /** Called only after the same shell's actual native physics postupdate. */
    public static synchronized void observePassage(SAOIsoPlayerShell body){
        var p=PASSAGES.get(body);if(p==null)return;
        var door=p.door.get();var current=body.getCurrentSquare();var last=body.getLastSquare();
        if(!p.actor.equals(SAOConceptObservation.actor(body))||p.cell.get()!=body.getCell()
            ||!usableDoor(door)||door.getObjectIndex()<0){PASSAGES.remove(body);return;}
        if(last==p.from.get()&&current==p.to.get()&&open(door)
            &&door.getSquare()!=null&&(door.getSquare()==p.from.get()||door.getSquare()==p.to.get()))p.matched=true;
        p.last=new WeakReference<>(current);
    }
    public static synchronized boolean passage(SAOIsoPlayerShell body,String token){
        var p=PASSAGES.get(body);
        return p!=null&&p.token.equals(token)&&p.actor.equals(SAOConceptObservation.actor(body))&&p.cell.get()==body.getCell()&&p.matched;
    }
    public static synchronized void forgetPassage(SAOIsoPlayerShell body,String token){
        var p=PASSAGES.get(body);if(p!=null&&p.token.equals(token))PASSAGES.remove(body);
    }
    public static synchronized boolean recoveryValid(SAOIsoPlayerShell body,String key,String revision,double x,double y,double z,boolean reached){
        String actor=SAOConceptObservation.actor(body);var sites=SITES.get(body);var s=sites==null?null:sites.get(key);
        if(actor==null||s==null||!actor.equals(s.actor)||!s.revision.equals(revision)||!Double.isFinite(x)||!Double.isFinite(y)
            ||!Double.isFinite(z)||z!=s.z||body.getCell()!=s.square.get().getCell())return false;
        var door=s.previous.get();var anchor=s.inside.get();var target=body.getCell().getGridSquare((int)Math.floor(x),(int)Math.floor(y),(int)z);
        if(!usableDoor(door)||open(door)||door.getObjectIndex()<0||door.getSquare()!=s.square.get()
            ||anchor==null||target==null||!target.haveRoof||!anchor.haveRoof||!visible(body,target))return false;
        var original=anchor.getIsoWorldRegion();var current=target.getIsoWorldRegion();
        boolean sameRoom=anchor.getRoom()!=null&&anchor.getRoom()==target.getRoom();
        boolean sameRegion=original!=null&&original==current;
        if(!sameRoom&&!sameRegion||!(current instanceof zombie.iso.areas.isoregion.regions.IsoWorldRegion region)
            ||!region.isEnclosed()||!region.isFullyRoofed())return false;
        return !reached||body.getCurrentSquare()==target&&Math.hypot(body.getX()-x,body.getY()-y)<=.35&&Math.abs(body.getZ()-z)<.1;
    }
    public static KahluaTable cover(SAOIsoPlayerShell body,int x,int y,int z){
        var t=table();var sq=body.getCell().getGridSquare(x,y,z);
        if(SAOConceptObservation.actor(body)==null||sq==null||body.getCurrentSquare()!=sq||!visible(body,sq))return t;
        var region=sq.getIsoWorldRegion();t.rawset("reached",true);t.rawset("roof",sq.haveRoof);
        t.rawset("room",sq.isInARoom());t.rawset("outside",sq.isOutside());
        t.rawset("regionKnown",region!=null);t.rawset("enclosed",region instanceof zombie.iso.areas.isoregion.regions.IsoWorldRegion world&&world.isEnclosed());
        t.rawset("fullyRoofed",region!=null&&region.isFullyRoofed());
        t.rawset("roomId",sq.getRoomIDString());
        return t;
    }
}
