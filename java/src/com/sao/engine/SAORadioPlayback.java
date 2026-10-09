package com.sao.engine;

import java.lang.ref.WeakReference;
import java.lang.reflect.Method;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Map;
import java.util.WeakHashMap;
import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.characters.IsoPlayer;
import zombie.inventory.types.Radio;
import zombie.iso.IsoWorld;
import zombie.iso.objects.IsoWaveSignal;
import zombie.network.GameClient;
import zombie.network.GameServer;
import zombie.radio.ZomboidRadio;
import zombie.radio.devices.WaveSignalDevice;
import zombie.vehicles.VehiclePart;

/** Actual emitted native lines, bound at emission to a selected owned receiver. */
public final class SAORadioPlayback {
    private SAORadioPlayback() { }
    private static final Map<SAOIsoPlayerShell,Listener> LISTENERS=new WeakHashMap<>();
    private static final ThreadLocal<Radio> PORTABLE=new ThreadLocal<>();
    private static final ThreadLocal<Integer> DEPTH=ThreadLocal.withInitial(()->0);
    private static final Map<Radio,Integer> UPDATE_FRAMES=new WeakHashMap<>();
    private static Method nativeDistribution;
    private static long sequence;
    private static final class Listener {
        final String actor,bodyToken,workId,sourceKey;
        final double countyAtRegistration,engineAtRegistration;
        final WeakReference<WaveSignalDevice> source;
        final ArrayDeque<Emission> events=new ArrayDeque<>();
        Listener(SAOIsoPlayerShell body,String workId,WaveSignalDevice source,String key,double countyHours,double engineHours){
            this.actor=SAOConceptObservation.actor(body);
            this.bodyToken=String.valueOf(body.getModData().rawget("SAOExternalToken"));
            this.workId=workId;this.source=new WeakReference<>(source);this.sourceKey=key;
            this.countyAtRegistration=countyHours;this.engineAtRegistration=engineHours;
        }
    }
    private record Emission(long sequence,long nanoTime,double atHours,double engineAtHours,String text,String guid,
            String codes,int channel,short mediaIndex,float x,float y,float z) { }
    public record TextCall(WaveSignalDevice parent,String text,String guid,String codes,
            IsoPlayer recipient,boolean outer) { }
    private static boolean sp(){return !GameClient.client&&!GameServer.server;}
    private static boolean text(String value,int length){return value!=null&&!value.isBlank()&&value.length()<=length;}
    private static Radio equipped(SAOIsoPlayerShell body){
        var radio=body.getEquipedRadio();
        return radio!=null&&radio.getPlayer()==body&&radio.getDeviceData()!=null?radio:null;
    }
    private static boolean own(SAOIsoPlayerShell body,Listener listener){
        return sp()&&listener!=null&&listener.actor.equals(SAOConceptObservation.actor(body))
            &&listener.bodyToken.equals(String.valueOf(body.getModData().rawget("SAOExternalToken")));
    }
    private static boolean acquired(SAOIsoPlayerShell body,WaveSignalDevice source){
        if(source instanceof Radio radio)return radio.getPlayer()==body&&equipped(body)==radio;
        if(source instanceof IsoWaveSignal object)return object.getSquare()!=null
            &&SAOPerceptionScanner.canSeeWorldSquareNow(body,object.getSquare(),8);
        if(source instanceof VehiclePart part){
            var vehicle=part.getVehicle();if(vehicle==null||part.getInventoryItem()==null)return false;
            int seat=body.getVehicle()==vehicle?vehicle.getSeat(body):-1;
            return seat>=0&&vehicle.getCharacter(seat)==body||vehicle.getSquare()!=null
                &&SAOPerceptionScanner.canSeeWorldSquareNow(body,vehicle.getSquare(),8);
        }
        return false;
    }
    public static synchronized boolean register(SAOIsoPlayerShell body,String workId,Object source,String key){
        return register(body,workId,source,key,zombie.GameTime.getInstance().getWorldAgeHours());
    }
    public static synchronized boolean register(SAOIsoPlayerShell body,String workId,Object source,String key,double countyHours){
        double engineHours=zombie.GameTime.getInstance().getWorldAgeHours();
        if(!sp()||SAOConceptObservation.actor(body)==null||!text(workId,160)||!text(key,160)
            ||!Double.isFinite(countyHours)||!Double.isFinite(engineHours)
            ||!(source instanceof WaveSignalDevice device)||!acquired(body,device))return false;
        Listener previous=LISTENERS.get(body);
        if(previous!=null)return own(body,previous)&&previous.workId.equals(workId)
            &&previous.source.get()==device&&previous.sourceKey.equals(key)
            &&previous.countyAtRegistration==countyHours;
        LISTENERS.put(body,new Listener(body,workId,device,key,countyHours,engineHours));return true;
    }
    public static synchronized boolean unregister(SAOIsoPlayerShell body,String workId){
        Listener listener=LISTENERS.get(body);
        if(listener==null||!listener.workId.equals(workId))return false;
        LISTENERS.remove(body);return true;
    }
    private static boolean hears(SAOIsoPlayerShell body,WaveSignalDevice source){
        var data=source.getDeviceData();
        if(data==null||!data.getIsTurnedOn()||!Float.isFinite(data.getDeviceVolume())
            ||data.getDeviceVolume()<=0||!SAOPerceptionScanner.canReceiveRadioNow(body))return false;
        if(source instanceof Radio radio)return equipped(body)==radio;
        if(source instanceof IsoWaveSignal object)return data.getHeadphoneType()<0
            &&SAOPerceptionScanner.canHearSourceNow(body,object.getSquare(),data.getDeviceVolumeRange());
        if(source instanceof VehiclePart part){
            var vehicle=part.getVehicle();if(vehicle==null)return false;
            int seat=body.getVehicle()==vehicle?vehicle.getSeat(body):-1;
            if(seat>=0&&vehicle.getCharacter(seat)==body)return true;
            return data.getHeadphoneType()<0
                &&SAOPerceptionScanner.canHearSourceNow(body,vehicle.getSquare(),data.getDeviceVolumeRange());
        }
        return false;
    }
    /** Called only by the exact terminal native text-method advice. */
    public static TextCall enterText(Object object,Object[] args){
        int depth=DEPTH.get();DEPTH.set(depth+1);
        if(!(object instanceof WaveSignalDevice parent))return new TextCall(null,null,null,null,null,false);
        int offset=args.length==8&&args[0] instanceof IsoPlayer?1:0;
        if(args.length<offset+7||!(args[offset] instanceof String line))return new TextCall(null,null,null,null,null,false);
        IsoPlayer recipient=offset==1?(IsoPlayer)args[0]:null;
        if(recipient!=null&&(!(parent instanceof Radio radio)||radio.getPlayer()!=recipient
                ||recipient.isDead()||!recipient.isLocalPlayer()))return new TextCall(null,null,null,null,null,false);
        String guid=args[offset+4] instanceof String value?value:null;
        String codes=args[offset+5] instanceof String value?value:null;
        return new TextCall(parent,line,guid,codes,recipient,depth==0);
    }
    public static void exitText(TextCall call,Throwable failure){
        DEPTH.set(Math.max(0,DEPTH.get()-1));
        if(call==null||!call.outer||failure!=null||!sp()||!text(call.text,4096)
            ||call.guid!=null&&call.guid.length()>512||call.codes!=null&&call.codes.length()>4096)return;
        synchronized(SAORadioPlayback.class){
            for(var entry:LISTENERS.entrySet()){
                var body=entry.getKey();var listener=entry.getValue();
                if(!own(body,listener)||listener.source.get()!=call.parent
                    ||call.recipient!=null&&call.recipient!=body||!hears(body,call.parent))continue;
                double engineHours=zombie.GameTime.getInstance().getWorldAgeHours();
                double countyHours=listener.countyAtRegistration+(engineHours-listener.engineAtRegistration);
                if(!Double.isFinite(engineHours)||!Double.isFinite(countyHours)
                    ||engineHours<listener.engineAtRegistration)continue;
                if(listener.events.size()>=32)listener.events.removeFirst();
                var data=call.parent.getDeviceData();
                listener.events.addLast(new Emission(++sequence,System.nanoTime(),
                    countyHours,engineHours,call.text,call.guid,call.codes,
                    data.getChannel(),data.getMediaIndex(),call.parent.getX(),call.parent.getY(),call.parent.getZ()));
            }
        }
    }
    public static synchronized KahluaTable events(SAOIsoPlayerShell body,String workId,long after){
        Listener listener=LISTENERS.get(body);
        if(!own(body,listener)||!listener.workId.equals(workId))return null;
        KahluaTable out=LuaManager.platform.newTable();int n=0;
        for(Emission event:listener.events){
            if(event.sequence<=after||System.nanoTime()-event.nanoTime>5_000_000_000L)continue;
            var row=LuaManager.platform.newTable();row.rawset("actorId",listener.actor);
            row.rawset("workId",workId);row.rawset("sourceKey",listener.sourceKey);
            row.rawset("sequence",(double)event.sequence);row.rawset("atHours",event.atHours);
            row.rawset("engineAtHours",event.engineAtHours);
            row.rawset("clockAuthority","native-emission-registration-county-offset");
            row.rawset("text",event.text);row.rawset("guid",event.guid);row.rawset("codes",event.codes);
            row.rawset("channel",(double)event.channel);row.rawset("x",(double)event.x);
            row.rawset("mediaIndex",(double)event.mediaIndex);
            row.rawset("y",(double)event.y);row.rawset("z",(double)event.z);
            row.rawset("authority","native-emission-current-owned-receiver");
            out.rawset((double)++n,row);
        }
        return out;
    }
    public static synchronized boolean eventCurrent(SAOIsoPlayerShell body,String workId,long sequence,Object source){
        Listener listener=LISTENERS.get(body);
        if(!own(body,listener)||!listener.workId.equals(workId)||listener.source.get()!=source
            ||!(source instanceof WaveSignalDevice parent)||!hears(body,parent))return false;
        for(Emission event:listener.events){
            if(event.sequence==sequence)return System.nanoTime()-event.nanoTime<=5_000_000_000L
                &&zombie.GameTime.getInstance().getWorldAgeHours()>=event.engineAtHours
                &&parent.getDeviceData().getChannel()==event.channel
                &&parent.getDeviceData().getMediaIndex()==event.mediaIndex;
        }
        return false;
    }
    public static synchronized KahluaTable tick(SAOIsoPlayerShell body,String workId){
        Listener listener=LISTENERS.get(body);
        if(!own(body,listener)||!listener.workId.equals(workId))return null;
        var source=listener.source.get();if(source==null)return null;
        int frame=IsoWorld.instance.getFrameNo();boolean advanced=false;
        if(source instanceof Radio radio){
            if(equipped(body)!=radio)return null;
            Integer prior=UPDATE_FRAMES.get(radio);
            radio.update();advanced=prior==null||prior!=frame;
        }
        var result=LuaManager.platform.newTable();result.rawset("actorId",listener.actor);
        result.rawset("workId",workId);result.rawset("frameNo",(double)frame);
        result.rawset("nativeAdvanced",advanced);return result;
    }
    public static boolean privatePortableEvent(String event,Object parent){
        return "OnDeviceText".equals(event)&&parent instanceof Radio radio&&PORTABLE.get()==radio;
    }
    public static boolean privateChat(){return PORTABLE.get()!=null;}
    public static boolean updatePortable(Object object){
        if(!sp()||!(object instanceof Radio radio)||!(radio.getPlayer() instanceof SAOIsoPlayerShell body)
            ||!body.isExistInTheWorld()||body.isDead()||body.getCell()!=IsoWorld.instance.currentCell
            ||body.getModData().rawget("SAOPersonId")==null||body.getModData().rawget("SAOExternalOwner")!=null
            ||Boolean.TRUE.equals(body.getModData().rawget("ZAOOwned"))||equipped(body)!=radio)return false;
        for(IsoPlayer player:IsoPlayer.players)if(player==body)return false;
        int frame=IsoWorld.instance.getFrameNo();
        synchronized(SAORadioPlayback.class){
            Integer previousFrame=UPDATE_FRAMES.get(radio);
            if(previousFrame!=null&&previousFrame==frame)return true;
        }
        Radio previous=PORTABLE.get();PORTABLE.set(radio);
        try {
            radio.getDeviceData().update(false,true);
            synchronized(SAORadioPlayback.class){UPDATE_FRAMES.put(radio,frame);}return true;
        }
        finally {if(previous==null)PORTABLE.remove();else PORTABLE.set(previous);}
    }
    /** Extend only an actual original SP transmission, with its original arguments unchanged. */
    public static void distribute(Object original,Object[] args){
        if(!sp()||!(original instanceof ZomboidRadio radio)||args.length!=11
            ||Boolean.TRUE.equals(args[10])||IsoWorld.instance.currentCell==null)return;
        try {
            if(nativeDistribution==null){
                nativeDistribution=ZomboidRadio.class.getDeclaredMethod("DistributeToPlayer",IsoPlayer.class,
                    int.class,int.class,int.class,String.class,String.class,String.class,
                    float.class,float.class,float.class,int.class,boolean.class);
                nativeDistribution.setAccessible(true);
            }
            ArrayList<SAOIsoPlayerShell> listeners;
            synchronized(SAORadioPlayback.class){listeners=new ArrayList<>(LISTENERS.keySet());}
            for(var body:listeners){
                if(SAOConceptObservation.actor(body)==null)continue;
                Radio target=equipped(body);if(target==null)continue;
                synchronized(SAORadioPlayback.class){
                    Listener listener=LISTENERS.get(body);
                    if(!own(body,listener)||listener.source.get()!=target)continue;
                }
                var nativeArgs=new Object[12];nativeArgs[0]=body;System.arraycopy(args,0,nativeArgs,1,11);
                Radio previous=PORTABLE.get();PORTABLE.set(target);
                try {nativeDistribution.invoke(radio,nativeArgs);}
                finally {if(previous==null)PORTABLE.remove();else PORTABLE.set(previous);}
            }
        }catch(Throwable unavailable){com.sao.agent.SAOAgent.log("native radio distribution refused: "+unavailable);}
    }
    public static synchronized void resetRuntimeForWorld(){LISTENERS.clear();UPDATE_FRAMES.clear();PORTABLE.remove();DEPTH.remove();}
}
