package com.sao.engine;

import java.util.HashSet;
import java.util.Set;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.SpriteDetails.IsoFlagType;

/** Personally visible recovery means. These reads do not move or reserve a body. */
public final class SAORecoveryPlace {
    private SAORecoveryPlace() { }
    private static final int[][] SIDES={{-1,0},{1,0},{0,-1},{0,1}};

    private static boolean visible(SAOIsoPlayerShell body, IsoGridSquare square, int radius) {
        return SAOPerceptionScanner.canSeeWorldSquareNow(body,square,radius);
    }
    private static boolean occupied(SAOIsoPlayerShell body, IsoGridSquare square) {
        for (var other : square.getMovingObjects())
            if (other != body && other.isCharacter()) return true;
        return false;
    }
    private static boolean furnitureOccupied(SAOIsoPlayerShell body,IsoObject object) {
        if(object.isFurnitureOccupied(body))return true;
        // Native chair occupancy tests SitOnFurnitureAnim; sleeping beds instead use OnBedAnim.
        for(var other:body.getCell().getObjectList())
            if(other!=body && other instanceof zombie.characters.IsoPlayer player && player.isOnBed()
                    && (player.getSitOnFurnitureObject()==object || player.getBed()==object))return true;
        return false;
    }
    private static boolean free(SAOIsoPlayerShell body, IsoGridSquare square) {
        return square != null && square.isSolidFloor() && !square.isSolid() && !square.isSolidTrans()
            && !square.HasStairs() && !square.HasStairsBelow() && square.isFree(false) && !occupied(body,square);
    }
    private static boolean bed(IsoObject object) {
        return object != null && object.getSprite() != null && object.getProperties() != null
            && object.getProperties().has(IsoFlagType.bed);
    }
    private static String objectKey(IsoObject object) {
        return "bed:"+object.getX()+":"+object.getY()+":"+object.getZ()+":"+object.getObjectIndex()
            +":"+Integer.toHexString(System.identityHashCode(object));
    }
    private static KahluaTable row(String key,String kind,double x,double y,double z) {
        var row=LuaManager.platform.newTable();
        row.rawset("key",key);row.rawset("kind",kind);row.rawset("x",x);row.rawset("y",y);row.rawset("z",z);
        row.rawset("available",true);return row;
    }
    private static void count(KahluaTable report,String key) {
        if(report==null)return;
        Object value=report.rawget(key);report.rawset(key,value instanceof Double number?number+1:1.0);
    }
    private static boolean groundRejected(KahluaTable report,boolean visibility) {
        count(report,visibility?"groundRejectedVisibility":"groundRejectedClearance");return false;
    }
    /** Full lying envelope, including the integrated +.4,+.4 offset, must remain in visible free space. */
    private static boolean groundClear(SAOIsoPlayerShell body,double x,double y,double z,int radius) {
        return groundClear(body,x,y,z,radius,null);
    }
    private static boolean groundClear(SAOIsoPlayerShell body,double x,double y,double z,int radius,KahluaTable report) {
        if (!Double.isFinite(x) || !Double.isFinite(y) || !Double.isFinite(z)
                || z != Math.floor(body.getZ()) || body.getCurrentSquare().getRoom()==null) return groundRejected(report,false);
        var room=body.getCurrentSquare().getRoom();
        int minX=(int)Math.floor(x-0.85),maxX=(int)Math.floor(x+0.85);
        int minY=(int)Math.floor(y-0.85),maxY=(int)Math.floor(y+0.85);
        for(int sx=minX;sx<=maxX;sx++) for(int sy=minY;sy<=maxY;sy++) {
            var square=body.getCell().getGridSquare(sx,sy,(int)z);
            if (!visible(body,square,radius)) return groundRejected(report,true);
            if (square.getRoom()!=room || !free(body,square)) return groundRejected(report,false);
            // Door/window circulation is not a lying place, even when its aperture is open.
            for(int[] side:SIDES) {
                var adjacent=body.getCell().getGridSquare(sx+side[0],sy+side[1],(int)z);
                if (adjacent==null || square.getDoorTo(adjacent)!=null || square.getWindowTo(adjacent)!=null) return groundRejected(report,false);
                if (adjacent.getX()>=minX && adjacent.getX()<=maxX
                        && adjacent.getY()>=minY && adjacent.getY()<=maxY && square.isBlockedTo(adjacent)) return groundRejected(report,false);
            }
        }
        return true;
    }
    public static boolean groundClear(SAOIsoPlayerShell body,double x,double y,double z) {
        return SAOConceptObservation.actor(body)!=null && groundClear(body,x,y,z,8);
    }
    private static IsoObject head(SAOIsoPlayerShell body,IsoObject object,int radius) {
        var grid=object.getSprite().getSpriteGrid();
        String facing=object.getProperties().get("Facing");
        if(grid==null || facing==null) return null;
        int dx=0,dy=0;
        if(facing.equals("N") && grid.getSpriteGridPosY(object.getSprite())==0)dy=1;
        else if(facing.equals("S") && grid.getSpriteGridPosY(object.getSprite())==1)dy=-1;
        else if(facing.equals("W") && grid.getSpriteGridPosX(object.getSprite())==0)dx=1;
        else if(facing.equals("E") && grid.getSpriteGridPosX(object.getSprite())==1)dx=-1;
        if(dx==0 && dy==0)return object;
        var square=body.getCell().getGridSquare((int)object.getX()+dx,(int)object.getY()+dy,(int)object.getZ());
        if(!visible(body,square,radius))return null;
        for(int i=0;i<square.getObjects().size();i++) {
            var candidate=square.getObjects().get(i);
            if(bed(candidate) && candidate.getSprite().getSpriteGrid()==grid) return candidate;
        }
        return null;
    }
    private static KahluaTable bedRejected(KahluaTable diagnosis,String reason) {
        diagnosis.rawset("reason",reason);return null;
    }
    /** Join visible parts to the same observed source used by recovery admission.
     * An obscured or unresolved head supplies no identity beyond the visible part. */
    static String visibleSourceKey(SAOIsoPlayerShell body,IsoObject object,int radius) {
        if(!bed(object) || !visible(body,object.getSquare(),radius))return null;
        var resolved=head(body,object,radius);
        return objectKey(resolved==null?object:resolved);
    }
    private static KahluaTable bedPlace(SAOIsoPlayerShell body,IsoObject object,int radius,KahluaTable diagnosis) {
        String facing=object.getProperties().get("Facing");
        var grid=object.getSprite().getSpriteGrid();
        if(grid==null)return bedRejected(diagnosis,"visible-bed-grid-unavailable");
        diagnosis.rawset("facing",facing);diagnosis.rawset("gridWidth",(double)grid.getWidth());
        diagnosis.rawset("gridHeight",(double)grid.getHeight());
        if(furnitureOccupied(body,object))return bedRejected(diagnosis,"visible-bed-occupied");
        boolean vertical="N".equals(facing)||"S".equals(facing);
        if(!(vertical ? grid.getWidth()>=1 && grid.getWidth()<=2 && grid.getHeight()==2
                : grid.getWidth()==2 && grid.getHeight()>=1 && grid.getHeight()<=2))return bedRejected(diagnosis,"visible-bed-grid-unsupported");
        if(!vertical && !"E".equals(facing) && !"W".equals(facing))return bedRejected(diagnosis,"visible-bed-facing-unsupported");
        int footX=(int)object.getX()+("E".equals(facing)?1:"W".equals(facing)?-1:0);
        int footY=(int)object.getY()+("S".equals(facing)?1:"N".equals(facing)?-1:0);
        var foot=body.getCell().getGridSquare(footX,footY,(int)object.getZ());
        if(!visible(body,foot,radius))return bedRejected(diagnosis,"bed-foot-not-personally-visible");
        if(occupied(body,foot))return bedRejected(diagnosis,"visible-bed-foot-occupied");
        boolean matched=false;
        for(int i=0;i<foot.getObjects().size();i++) {
            var part=foot.getObjects().get(i);
            if(bed(part)&&part.getSprite().getSpriteGrid()==grid&&!furnitureOccupied(body,part))matched=true;
        }
        if(!matched)return bedRejected(diagnosis,"visible-bed-foot-match-or-occupancy-refused");
        if(occupied(body,object.getSquare()))return bedRejected(diagnosis,"visible-bed-head-occupied");
        if(object.getSquare().isWallTo(foot)
                || object.getSquare().isDoorTo(foot) || object.getSquare().isWindowTo(foot)
                || object.getSquare().isHoppableTo(foot))return bedRejected(diagnosis,"visible-bed-span-blocked");
        // All five installed onGetOnBed approaches, at adjacent tile centers.
        // PlayerOnBedState owns final .3/.7 alignment and ISGetOnBedAction selects the native entry side.
        // The final pair identifies the actual bed part touched by this approach, never a diagonal shortcut.
        double hx=object.getX(),hy=object.getY();
        double[][] approaches=vertical
            ? new double[][]{{hx-.5,hy+.5,hx,hy},{hx+1.5,hy+.5,hx,hy},
                {hx-.5,footY+.5,footX,footY},{hx+1.5,footY+.5,footX,footY},
                {hx+.5,footY+.5+(footY-hy),footX,footY}}
            : new double[][]{{hx+.5,hy-.5,hx,hy},{hx+.5,hy+1.5,hx,hy},
                {footX+.5,hy-.5,footX,footY},{footX+.5,hy+1.5,footX,footY},
                {footX+.5+(footX-hx),hy+.5,footX,footY}};
        KahluaTable best=null;double distance=Double.POSITIVE_INFINITY;
        for(double[] point:approaches) {
            var square=body.getCell().getGridSquare((int)Math.floor(point[0]),(int)Math.floor(point[1]),(int)object.getZ());
            var touched=body.getCell().getGridSquare((int)point[2],(int)point[3],(int)object.getZ());
            if(!visible(body,square,radius)){count(diagnosis,"approachRejectedVisibility");continue;}
            if(!free(body,square)){count(diagnosis,"approachRejectedClearance");continue;}
            if(square.getRoom()!=object.getSquare().getRoom()
                    ||square.isWallTo(touched)||square.isDoorTo(touched)
                    ||square.isWindowTo(touched)||square.isHoppableTo(touched)){
                count(diagnosis,"approachRejectedBoundary");continue;}
            double d=Math.pow(body.getX()-point[0],2)+Math.pow(body.getY()-point[1],2);
            if(d>=distance)continue;
            best=row(objectKey(object),"bed",point[0],point[1],object.getZ());distance=d;
            best.rawset("objectX",(double)object.getX());best.rawset("objectY",(double)object.getY());
            best.rawset("objectZ",(double)object.getZ());best.rawset("objectIndex",(double)object.getObjectIndex());
            best.rawset("basis","visible-native-bed-and-clear-approach");
        }
        return best!=null?best:bedRejected(diagnosis,"personally-visible-native-approach-unavailable");
    }
    public static KahluaTable observe(SAOIsoPlayerShell body,int radius) {
        String actor=SAOConceptObservation.actor(body);
        if(actor==null||radius<1||radius>8)return null;
        var result=LuaManager.platform.newTable();var places=LuaManager.platform.newTable();
        result.rawset("actorId",actor);result.rawset("status","available");result.rawset("places",places);
        var report=LuaManager.platform.newTable();var rejections=LuaManager.platform.newTable();
        result.rawset("diagnostics",report);report.rawset("schema","sao.recovery-place-diagnostics/1");
        report.rawset("bodyAdmission","accepted");report.rawset("bedRejections",rejections);
        report.rawset("nativeAsleep",body.isAsleep());report.rawset("nativeOnBed",body.isOnBed());
        for(String key:new String[]{"visibleSquares","visibleBedParts","uniqueBeds","admissibleBeds","unavailableBeds",
                "admissibleGround","groundRejectedVisibility","groundRejectedClearance"})report.rawset(key,0.0);
        var eye=body.getCurrentSquare();Set<IsoObject> seen=new HashSet<>();int count=0;
        for(int r=0;r<=radius;r++)for(int dx=-r;dx<=r;dx++)for(int dy=-r;dy<=r;dy++) {
            if(Math.max(Math.abs(dx),Math.abs(dy))!=r)continue;
            var square=body.getCell().getGridSquare(eye.getX()+dx,eye.getY()+dy,eye.getZ());
            if(!visible(body,square,radius))continue;
            count(report,"visibleSquares");
            for(int i=0;i<square.getObjects().size();i++) {
                var object=square.getObjects().get(i);if(!bed(object))continue;
                count(report,"visibleBedParts");
                var resolvedHead=head(body,object,radius);var head=resolvedHead==null?object:resolvedHead;
                if(!seen.add(head))continue;
                count(report,"uniqueBeds");var diagnosis=LuaManager.platform.newTable();
                diagnosis.rawset("key",objectKey(head));diagnosis.rawset("sprite",head.getSprite().getName());
                var candidate=resolvedHead==null?bedRejected(diagnosis,"visible-bed-grid-or-head-unavailable"):bedPlace(body,head,radius,diagnosis);
                if(candidate==null){candidate=row(objectKey(head),"bed",head.getX()+.5,head.getY()+.5,head.getZ());
                    candidate.rawset("available",false);candidate.rawset("reason","native-bed-approach-unavailable");
                    count(report,"unavailableBeds");if(rejections.len()<16)rejections.rawset((double)rejections.len()+1,diagnosis);
                }else count(report,"admissibleBeds");
                if(count<64)places.rawset((double)++count,candidate);
            }
            double x=square.getX()+.5,y=square.getY()+.5;
            if(count<64 && groundClear(body,x,y,eye.getZ(),radius,report) && groundClear(body,x+.4,y+.4,eye.getZ(),radius,report)) {
                var candidate=row("ground:"+square.getX()+":"+square.getY()+":"+square.getZ(),"ground",x,y,eye.getZ());
                candidate.rawset("basis","visible-clear-lying-envelope");places.rawset((double)++count,candidate);
                count(report,"admissibleGround");
            }
        }
        return result;
    }
    /** Resolve only after exact native approach; callers retain the returned object privately. */
    public static IsoObject resolveBed(SAOIsoPlayerShell body,String key) {
        var view=observe(body,8);if(view==null||key==null)return null;
        var places=(KahluaTable)view.rawget("places");
        for(int i=1;i<=places.len();i++) {
            var place=(KahluaTable)places.rawget((double)i);
            if(!key.equals(place.rawget("key"))||!"bed".equals(place.rawget("kind"))||!Boolean.TRUE.equals(place.rawget("available")))continue;
            double x=(Double)place.rawget("x"),y=(Double)place.rawget("y"),z=(Double)place.rawget("z");
            if(Math.hypot(body.getX()-x,body.getY()-y)>.35||Math.abs(body.getZ()-z)>.1)return null;
            var square=body.getCell().getGridSquare(((Double)place.rawget("objectX")).intValue(),((Double)place.rawget("objectY")).intValue(),(int)z);
            int index=((Double)place.rawget("objectIndex")).intValue();
            return square!=null&&index>=0&&index<square.getObjects().size()?square.getObjects().get(index):null;
        }
        return null;
    }
}
