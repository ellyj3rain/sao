package com.sao.engine;

import java.lang.ref.WeakReference;
import java.util.Map;
import java.util.Objects;
import java.util.WeakHashMap;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaClosure;
import zombie.Lua.LuaManager;
import zombie.characters.CharacterTimedActions.BaseAction;
import zombie.core.skinnedmodel.animation.AnimationTrack;
import zombie.core.skinnedmodel.animation.IAnimListener;
import zombie.network.GameClient;
import zombie.network.GameServer;

/** Native loop receipts for exact source partner clips on a maintained native action. */
public final class SAODanceCycle {
    private SAODanceCycle() { }
    private static final Map<SAOIsoPlayerShell,Binding> BINDINGS=new WeakHashMap<>();
    private static long sequence;
    private static final ThreadLocal<PerformCall> PERFORM=new ThreadLocal<>();
    public static final class PerformCall {
        final BaseAction action;final Binding binding;final long sequence;final PerformCall prior;
        PerformCall(BaseAction action,Binding binding,long sequence,PerformCall prior){
            this.action=action;this.binding=binding;this.sequence=sequence;this.prior=prior;
        }
    }
    private static boolean allowed(String clip){return "Bob_DancingDiscoSourceDefault".equals(clip)
        ||"Bob_DancingDiscoTargetDefault".equals(clip);}
    private static final class Binding implements IAnimListener {
        final WeakReference<SAOIsoPlayerShell> body;
        final WeakReference<BaseAction> action;
        final String actor,workId,clip;
        final Object token;
        final KahluaTable music;
        final LuaClosure guard;
        final KahluaThread luaThread;
        final Thread javaThread;
        WeakReference<AnimationTrack> track=new WeakReference<>(null);
        long sequence,nanoTime;double engineAtHours;
        Binding(SAOIsoPlayerShell body,BaseAction action,String workId,String clip,KahluaTable music,LuaClosure guard){
            this.body=new WeakReference<>(body);this.action=new WeakReference<>(action);
            actor=SAOConceptObservation.actor(body);token=body.getModData().rawget("SAOExternalToken");
            this.workId=workId;this.clip=clip;
            this.music=music;this.guard=guard;luaThread=LuaManager.thread;javaThread=Thread.currentThread();
        }
        public void onAnimStarted(AnimationTrack track) { }
        public void onLoopedAnim(AnimationTrack emitted){
            synchronized(SAODanceCycle.class){
                var body=this.body.get();
                try {
                    if(body==null||BINDINGS.get(body)!=this||!current(body,this)||track.get()!=emitted){sequence=0;return;}
                    sequence=++SAODanceCycle.sequence;nanoTime=System.nanoTime();
                    engineAtHours=zombie.GameTime.getInstance().getWorldAgeHours();
                }catch(Throwable unavailable){sequence=0;}
            }
        }
        public void onNonLoopedAnimFadeOut(AnimationTrack track) { }
        public void onNonLoopedAnimFinished(AnimationTrack track) { }
        public void onNoAnimConditionsPass() { }
        public void onTrackDestroyed(AnimationTrack destroyed){
            synchronized(SAODanceCycle.class){if(track.get()==destroyed){track.clear();sequence=0;}}
        }
    }
    private static KahluaTable music(){
        if(LuaManager.env==null||!(LuaManager.env.rawget("SAO") instanceof KahluaTable sao))return null;
        return sao.rawget("LeisureMusic") instanceof KahluaTable music?music:null;
    }
    private static boolean admitted(SAOIsoPlayerShell body,Binding binding){
        try {
            return binding.javaThread==Thread.currentThread()&&binding.luaThread!=null
                &&binding.luaThread==LuaManager.thread&&music()==binding.music
                &&binding.music.rawget("nativeDanceCycleAllowed")==binding.guard&&LuaManager.caller!=null
                &&Boolean.TRUE.equals(LuaManager.caller.pcallBoolean(binding.luaThread,binding.guard,body,binding.workId,binding.clip));
        }catch(Throwable unavailable){return false;}
    }
    private static boolean owned(SAOIsoPlayerShell body,Binding binding){
        return maintained(body,binding)&&binding.clip.equals(body.getVariableString("PerformingAction"));
    }
    private static boolean maintained(SAOIsoPlayerShell body,Binding binding){
        var action=binding.action.get();
        return !GameClient.client&&!GameServer.server&&binding.actor.equals(SAOConceptObservation.actor(body))
            &&Objects.equals(binding.token,body.getModData().rawget("SAOExternalToken"))
            &&!body.isAsleep()&&action!=null&&action.chr==body&&action.isStarted()
            &&body.checkCurrentAction(current->current==action)
            &&admitted(body,binding);
    }
    private static boolean current(SAOIsoPlayerShell body,Binding binding){
        if(!owned(body,binding))return false;
        var player=SAOOrientationAnimation.nativePlayer(body);var track=binding.track.get();
        if(player==null||track==null||!player.getMultiTrack().getTracks().contains(track)
            ||track.getClip()==null||!binding.clip.equals(track.getClip().name)||!track.isLooping()
            ||!(track.getBlendWeight()>0))return false;
        int matching=0;
        for(var candidate:player.getMultiTrack().getTracks()){
            if(candidate.getClip()!=null&&binding.clip.equals(candidate.getClip().name)
                &&candidate.isLooping()&&candidate.getBlendWeight()>0)matching++;
        }
        return matching==1;
    }
    private static void detach(Binding binding){
        var prior=binding.track.get();if(prior!=null)prior.removeListener(binding);
        binding.track.clear();binding.sequence=0;
    }
    private static boolean recent(SAOIsoPlayerShell body,Binding binding){
        return current(body,binding)&&binding.sequence>0
            &&System.nanoTime()-binding.nanoTime<=5_000_000_000L
            &&Double.isFinite(binding.engineAtHours)
            &&zombie.GameTime.getInstance().getWorldAgeHours()>=binding.engineAtHours;
    }
    public static synchronized boolean register(SAOIsoPlayerShell body,String workId,Object action,String clip){
        if(SAOConceptObservation.actor(body)==null||workId==null||workId.isBlank()||workId.length()>160
            ||!allowed(clip)||!(action instanceof BaseAction nativeAction))return false;
        Binding prior=BINDINGS.get(body);
        if(prior!=null)return prior.workId.equals(workId)&&prior.action.get()==nativeAction
            &&prior.clip.equals(clip)&&owned(body,prior);
        var music=music();
        if(music==null||!(music.rawget("nativeDanceCycleAllowed") instanceof LuaClosure guard))return false;
        var binding=new Binding(body,nativeAction,workId,clip,music,guard);
        if(!owned(body,binding))return false;
        BINDINGS.put(body,binding);return true;
    }
    public static synchronized KahluaTable observe(SAOIsoPlayerShell body,String workId){
        Binding binding=BINDINGS.get(body);
        if(binding==null||!binding.workId.equals(workId))return null;
        if(!owned(body,binding)){detach(binding);return null;}
        var player=SAOOrientationAnimation.nativePlayer(body);
        if(player==null){detach(binding);return null;}
        AnimationTrack selected=null;
        for(var track:player.getMultiTrack().getTracks()){
            if(track.getClip()!=null&&binding.clip.equals(track.getClip().name)&&track.isLooping()&&track.getBlendWeight()>0){
                if(selected!=null){detach(binding);return null;}selected=track;
            }
        }
        var previous=binding.track.get();
        if(previous!=selected){
            if(previous!=null)previous.removeListener(binding);
            binding.track=new WeakReference<>(selected);binding.sequence=0;
            if(selected!=null)selected.addListener(binding);
        }
        if(!recent(body,binding))return null;
        var row=LuaManager.platform.newTable();row.rawset("actorId",binding.actor);row.rawset("bodyToken",binding.token);
        row.rawset("workId",binding.workId);row.rawset("sequence",(double)binding.sequence);
        row.rawset("clip",binding.clip);row.rawset("engineAtHours",binding.engineAtHours);
        row.rawset("authority","native-current-owned-source-animation-loop");return row;
    }
    public static synchronized boolean eventCurrent(SAOIsoPlayerShell body,String workId,long sequence){
        var binding=BINDINGS.get(body);
        return binding!=null&&binding.workId.equals(workId)&&binding.sequence==sequence&&recent(body,binding);
    }
    /** Called only by advice around the installed native LuaTimedActionNew.perform. */
    public static synchronized PerformCall enterPerform(Object object){
        try {
            if(!(object instanceof BaseAction action))return null;
            var prior=PERFORM.get();Binding binding=action.chr instanceof SAOIsoPlayerShell body?BINDINGS.get(body):null;
            if(binding==null&&prior==null)return null;
            if(binding!=null&&(binding.action.get()!=action||!recent(binding.body.get(),binding)))binding=null;
            var call=new PerformCall(action,binding,binding==null?0:binding.sequence,prior);PERFORM.set(call);return call;
        }catch(Throwable unavailable){PERFORM.remove();return null;}
    }
    public static void exitPerform(PerformCall call){
        if(call==null)return;
        if(call.prior==null)PERFORM.remove();else PERFORM.set(call.prior);
    }
    public static synchronized boolean completionCurrent(SAOIsoPlayerShell body,String workId,long sequence){
        var call=PERFORM.get();var binding=BINDINGS.get(body);
        return com.sao.agent.SAODanceCycleWeave.ready()&&call!=null&&binding!=null&&call.binding==binding
            &&call.action==binding.action.get()&&binding.workId.equals(workId)&&call.sequence==sequence
            &&binding.sequence==sequence&&sequence>0&&maintained(body,binding)
            &&System.nanoTime()-binding.nanoTime<=5_000_000_000L&&Double.isFinite(binding.engineAtHours)
            &&zombie.GameTime.getInstance().getWorldAgeHours()>=binding.engineAtHours;
    }
    public static synchronized boolean unregister(SAOIsoPlayerShell body,String workId){
        var binding=BINDINGS.get(body);if(binding==null||!binding.workId.equals(workId))return false;
        var track=binding.track.get();if(track!=null)track.removeListener(binding);
        BINDINGS.remove(body);return true;
    }
    public static synchronized void resetRuntimeForWorld(){
        for(var binding:BINDINGS.values()){var track=binding.track.get();if(track!=null)track.removeListener(binding);}
        BINDINGS.clear();PERFORM.remove();
    }
}
