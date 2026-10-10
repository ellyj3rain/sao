package com.sao.engine;

import java.util.*;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoObject;
import zombie.iso.objects.IsoThumpable;
import zombie.iso.SpriteDetails.IsoFlagType;

/** Person-bound observed bed footprints. Native construction and recovery own effects. */
public final class SAOBedConstruction {
    private SAOBedConstruction() { }
    private static final Map<SAOIsoPlayerShell,LinkedHashMap<String,Site>> SITES=new WeakHashMap<>();
    private static final int[][] SIDES={{-1,0},{1,0},{0,-1},{0,1}};
    private static boolean visible(SAOIsoPlayerShell body,IsoGridSquare square) {
        return SAOPerceptionScanner.canSeeWorldSquareNow(body,square,8);
    }
    private static boolean free(SAOIsoPlayerShell body,IsoGridSquare square) {
        if(square==null||!square.isSolidFloor()||!square.isFree(false)||square.isSolid()||square.isSolidTrans()
            ||square.HasStairs()||square.HasStairsBelow()||square.HasTree()||square.isVehicleIntersecting()||square.haveFire())return false;
        for(var moving:square.getMovingObjects())if(moving!=body&&moving.isCharacter())return false;
        return true;
    }
    private static int width(String face){return "S".equals(face)?2:1;}
    private static int height(String face){return "S".equals(face)?1:2;}
    private static boolean face(String face){return "S".equals(face)||"E".equals(face);}
    private static boolean boundary(IsoGridSquare a,IsoGridSquare b) {
        return a.isBlockedTo(b)||a.isWallTo(b)||a.isDoorTo(b)||a.isWindowTo(b)||a.isHoppableTo(b);
    }
    private static boolean recoverySide(IsoGridSquare base,String face,int x,int y,int sx,int sy) {
        // Native recovery has five approaches: both sides of both parts and
        // the foot end. The head-end tile is not an entry side.
        return !(x==0&&y==0&&("S".equals(face)?sx==base.getX()-1&&sy==base.getY():sy==base.getY()-1&&sx==base.getX()));
    }
    private static boolean exactApproach(SAOIsoPlayerShell body,IsoGridSquare base,String face,int ax,int ay) {
        var square=body.getCell().getGridSquare(ax,ay,base.getZ());
        if(!visible(body,square)||!free(body,square)||square.getRoom()!=base.getRoom())return false;
        for(int x=0;x<width(face);x++)for(int y=0;y<height(face);y++)
            if(Math.abs(ax-base.getX()-x)+Math.abs(ay-base.getY()-y)==1&&recoverySide(base,face,x,y,ax,ay)
                &&!boundary(square,body.getCell().getGridSquare(base.getX()+x,base.getY()+y,base.getZ())))return true;
        return false;
    }
    private static IsoGridSquare approach(SAOIsoPlayerShell body,IsoGridSquare base,String face) {
        IsoGridSquare best=null;double distance=Double.POSITIVE_INFINITY;
        for(int x=0;x<width(face);x++)for(int y=0;y<height(face);y++){
            var touched=body.getCell().getGridSquare(base.getX()+x,base.getY()+y,base.getZ());
            for(int[] side:SIDES){
                int sx=base.getX()+x+side[0],sy=base.getY()+y+side[1];
                if(sx>=base.getX()&&sx<base.getX()+width(face)&&sy>=base.getY()&&sy<base.getY()+height(face))continue;
                var sq=body.getCell().getGridSquare(sx,sy,base.getZ());
                if(!recoverySide(base,face,x,y,sx,sy)||!visible(body,sq)||!free(body,sq)||sq.getRoom()!=base.getRoom()||boundary(sq,touched))continue;
                double d=Math.pow(body.getX()-sx-.5,2)+Math.pow(body.getY()-sy-.5,2);
                if(d<distance){best=sq;distance=d;}
            }
        }
        return best;
    }
    private static boolean footprint(SAOIsoPlayerShell body,IsoGridSquare base,String face) {
        if(!face(face)||base==null||body.getCell()!=base.getCell()||Math.floor(body.getZ())!=base.getZ())return false;
        for(int x=0;x<width(face);x++)for(int y=0;y<height(face);y++){
            var square=body.getCell().getGridSquare(base.getX()+x,base.getY()+y,base.getZ());
            if(!visible(body,square)||!free(body,square)||square.getRoom()!=base.getRoom())return false;
            if(square!=base&&boundary(base,square))return false;
        }
        return approach(body,base,face)!=null;
    }
    private static final class Snapshot {
        final java.lang.ref.WeakReference<IsoGridSquare> square;
        final ArrayList<java.lang.ref.WeakReference<IsoObject>> objects=new ArrayList<>();
        final ArrayList<String> sprites=new ArrayList<>();
        Snapshot(IsoGridSquare sq){
            square=new java.lang.ref.WeakReference<>(sq);
            for(int i=0;i<sq.getObjects().size();i++){
                var o=sq.getObjects().get(i);objects.add(new java.lang.ref.WeakReference<>(o));sprites.add(o.getSpriteName());
            }
        }
        boolean matches(IsoGridSquare sq){
            if(square.get()!=sq||sq==null||objects.size()!=sq.getObjects().size())return false;
            for(int i=0;i<objects.size();i++)if(objects.get(i).get()!=sq.getObjects().get(i)
                ||!Objects.equals(sprites.get(i),sq.getObjects().get(i).getSpriteName()))return false;
            return true;
        }
    }
    private static final class Site {
        final String actor,face,revision=UUID.randomUUID().toString();
        final ArrayList<Snapshot> tiles=new ArrayList<>();
        final Snapshot approach;
        final int x,y,z,ax,ay;
        Site(String actor,SAOIsoPlayerShell body,IsoGridSquare base,String face,IsoGridSquare approach){
            this.actor=actor;this.face=face;x=base.getX();y=base.getY();z=base.getZ();ax=approach.getX();ay=approach.getY();
            for(int sx=0;sx<width(face);sx++)for(int sy=0;sy<height(face);sy++)tiles.add(new Snapshot(body.getCell().getGridSquare(x+sx,y+sy,z)));
            this.approach=new Snapshot(approach);
        }
        boolean matches(String actor,SAOIsoPlayerShell body){
            if(!this.actor.equals(actor))return false;int i=0;
            for(int sx=0;sx<width(face);sx++)for(int sy=0;sy<height(face);sy++)if(!tiles.get(i++).matches(body.getCell().getGridSquare(x+sx,y+sy,z)))return false;
            return approach.matches(body.getCell().getGridSquare(ax,ay,z));
        }
    }
    public static synchronized String observe(SAOIsoPlayerShell body) {
        String actor=SAOConceptObservation.actor(body);if(actor==null)return "";
        var sites=SITES.computeIfAbsent(body,ignored->new LinkedHashMap<>());var eye=body.getCurrentSquare();StringBuilder out=new StringBuilder();int count=0;
        for(int r=0;r<=8&&count<32;r++)for(int dy=-r;dy<=r&&count<32;dy++)for(int dx=-r;dx<=r&&count<32;dx++){
            if(Math.max(Math.abs(dx),Math.abs(dy))!=r)continue;
            var base=body.getCell().getGridSquare(eye.getX()+dx,eye.getY()+dy,eye.getZ());
            for(String face:new String[]{"S","E"}){
                if(count>=32)break;if(!footprint(body,base,face))continue;
                var approach=approach(body,base,face);String key=base.getX()+":"+base.getY()+":"+base.getZ()+":"+face;
                var site=sites.get(key);
                if(site==null||!site.matches(actor,body)||!exactApproach(body,base,face,site.ax,site.ay)){site=new Site(actor,body,base,face,approach);sites.put(key,site);}
                if(out.length()>0)out.append('|');
                out.append(site.x).append(',').append(site.y).append(',').append(site.z).append(',').append(face.replace('|', '_').replace(',', '_')).append(',')
                    .append(site.revision.replace('|', '_').replace(',', '_')).append(',').append(site.ax).append(',').append(site.ay).append(',').append(site.z);count++;
            }
        }
        while(sites.size()>128)sites.remove(sites.keySet().iterator().next());
        return out.toString();
    }
    public static synchronized IsoGridSquare placement(SAOIsoPlayerShell body,int x,int y,int z,String face,String revision) {
        String actor=SAOConceptObservation.actor(body);var sites=SITES.get(body);var site=sites==null?null:sites.get(x+":"+y+":"+z+":"+face);
        var base=actor==null?null:body.getCell().getGridSquare(x,y,z);
        return site!=null&&site.revision.equals(revision)&&site.matches(actor,body)&&footprint(body,base,face)
            && exactApproach(body,base,face,site.ax,site.ay)
            && Math.hypot(body.getX()-site.ax-.5,body.getY()-site.ay-.5)<=.35&&Math.abs(body.getZ()-z)<.1?base:null;
    }
    public static boolean created(SAOIsoPlayerShell body,IsoThumpable first,IsoThumpable second,int x,int y,int z,String face) {
        if(SAOConceptObservation.actor(body)==null||!face(face)||first==null||second==null||first==second)return false;
        var grid=first.getSprite()==null?null:first.getSprite().getSpriteGrid();
        if(grid==null||grid.getWidth()!=width(face)||grid.getHeight()!=height(face)
            ||second.getSprite()==null||second.getSprite().getSpriteGrid()!=grid)return false;
        String[] names="S".equals(face)?new String[]{"carpentry_02_72","carpentry_02_73"}:new String[]{"carpentry_02_75","carpentry_02_74"};
        IsoThumpable[] parts={first,second};int i=0;
        for(int sx=0;sx<width(face);sx++)for(int sy=0;sy<height(face);sy++){
            var part=parts[i];var sq=body.getCell().getGridSquare(x+sx,y+sy,z);
            if(sq==null||!visible(body,sq)||part.getSquare()!=sq||part.getCell()!=body.getCell()
                ||part.getObjectIndex()<0||!sq.getObjects().contains(part)||!names[i].equals(part.getSpriteName())
                ||part.getProperties()==null||!part.getProperties().has(IsoFlagType.bed)
                ||!("S".equals(face)?"E":"S").equals(part.getProperties().get("Facing"))
                ||part.getEntityScript()==null||!"Base.Wood_Bed".equals(part.getEntityScript().getFullName()))return false;i++;
        }
        return true;
    }
}
