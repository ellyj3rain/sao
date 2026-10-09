import com.sao.engine.*;
import com.sao.bridge.SAOBridge;
import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import zombie.Lua.LuaManager;
import zombie.characters.*;
import zombie.characters.CharacterTimedActions.BaseAction;
import zombie.core.skinnedmodel.animation.*;
import zombie.core.skinnedmodel.model.*;
import zombie.core.skinnedmodel.model.jassimp.*;
import zombie.core.skinnedmodel.advancedanimation.AnimNode;
import zombie.iso.*;
import org.lwjgl.util.vector.Matrix4f;

/** Installed FBX importer and original native track Update; no rendered game loop. */
public final class DanceCycleProbe {
    static int checks; static KahluaTable env,music; static KahluaThread thread;
    static final String SOURCE="Bob_DancingDiscoSourceDefault", TARGET="Bob_DancingDiscoTargetDefault";
    static Field field(Class<?> type,String name)throws Exception {var f=type.getDeclaredField(name);f.setAccessible(true);return f;}
    static void check(String name,boolean pass){System.out.println("DANCE_CYCLE:"+name+"="+pass);if(!pass)throw new AssertionError("DANCE_CYCLE:"+name);checks++;}
    static void lua(String text)throws Exception{thread.call(LuaCompiler.loadstring(text,"dance-guard-host",env),null,null,null);}
    @SuppressWarnings("unchecked") static SkinningData importClip(Path path,SkinningData skin)throws Exception {
        var p=ProcessedAiSceneParams.create();p.scene=jassimp.Jassimp.importFile(path.toString());p.mode=JAssImpImporter.LoadMode.Normal;p.animBonesScaleModifier=1;p.skinnedTo=skin;
        var imported=ImportedSkeleton.process(ImportedSkeletonParams.create(p,p.scene.getMeshes().get(0)));
        var clips=(HashMap<String,AnimationClip>)field(ImportedSkeleton.class,"clips").get(imported);
        System.out.println("IMPORTED "+path+" "+clips.keySet());
        if(skin==null)return new SkinningData(clips,(List<Matrix4f>)field(ImportedSkeleton.class,"bindPose").get(imported),
            (List<Matrix4f>)field(ImportedSkeleton.class,"invBindPose").get(imported),(List<Matrix4f>)field(ImportedSkeleton.class,"skinOffsetMatrices").get(imported),
            (List<Integer>)field(ImportedSkeleton.class,"skeletonHierarchy").get(imported),(HashMap<String,Integer>)field(ImportedSkeleton.class,"boneIndices").get(imported));
        skin.animationClips.putAll(clips);return skin;
    }
    static AnimationPlayer player(SAOIsoPlayerShell body,SkinningData skin)throws Exception{
        var ctor=AnimationPlayer.class.getDeclaredConstructor();ctor.setAccessible(true);var p=ctor.newInstance();
        field(AnimationPlayer.class,"skinningData").set(p,skin);field(IsoGameCharacter.class,"animPlayer").set(body,p);return p;
    }
    static SAOIsoPlayerShell body(IsoCell cell,String id)throws Exception{
        var method=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);method.setAccessible(true);var b=(SAOIsoPlayerShell)method.invoke(null,cell);
        b.setNpc(true);b.playerIndex=1;b.setSquare(b.getCurrentSquare());b.getCurrentSquare().getMovingObjects().add(b);cell.getObjectList().add(b);
        b.getModData().rawset("SAOPersonId",id);b.getModData().rawset("SAOExternalToken","token:"+id);return b;
    }
    static BaseAction action(SAOIsoPlayerShell body,String clip){
        body.getCharacterActions().clear();var a=new BaseAction(body);a.maxTime=-1;body.StartAction(a);a.waitToStart();body.setVariable("PerformingAction",clip);return a;
    }
    static AnimationTrack track(AnimationPlayer p,AnimationClip clip,AnimNode node,boolean loop){
        var t=AnimationTrack.alloc();t.startClip(clip,loop,Float.parseFloat(node.speedScale));t.setBlendWeight(1);p.getMultiTrack().addTrack(t);return t;
    }
    static KahluaTable observe(SAOIsoPlayerShell b){return (KahluaTable)SAOBridge.INSTANCE.observeNativeDanceCycle(b,"work");}
    static boolean current(SAOIsoPlayerShell b,long s){return SAOBridge.INSTANCE.nativeDanceCycleCurrent(b,"work",s);}
    static long sequence(KahluaTable row){return ((Number)row.rawget("sequence")).longValue();}
    static void loop(AnimationTrack t){t.Update(t.getDuration()/t.getSpeedDelta()+.01f);}
    static double[] pose(AnimationTrack t,SkinningData skin){
        var out=new double[skin.numBones()*7];var position=new org.lwjgl.util.vector.Vector3f();var rotation=new org.lwjgl.util.vector.Quaternion();var scale=new org.lwjgl.util.vector.Vector3f();
        for(int i=0;i<skin.numBones();i++){t.get(i,position,rotation,scale);int j=i*7;out[j]=position.x;out[j+1]=position.y;out[j+2]=position.z;out[j+3]=rotation.x;out[j+4]=rotation.y;out[j+5]=rotation.z;out[j+6]=rotation.w;}return out;
    }
    static double difference(double[] a,double[] b){double d=0;for(int i=0;i<a.length;i++)d+=Math.abs(a[i]-b[i]);return d;}
    static void expire(SAOIsoPlayerShell b)throws Exception{
        var bindings=(Map<?,?>)field(SAODanceCycle.class,"BINDINGS").get(null);var binding=bindings.get(b);field(binding.getClass(),"nanoTime").setLong(binding,System.nanoTime()-6_000_000_000L);
    }
    public static void main(String[] args)throws Exception{
        Thread.setDefaultUncaughtExceptionHandler((thread,error)->{error.printStackTrace();System.exit(1);});
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);var cell=(IsoCell)boot.invoke(null);
        var platform=new J2SEPlatform();env=platform.newEnvironment();thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;LuaManager.converterManager=new KahluaConverterManager();LuaManager.caller=new LuaCaller(LuaManager.converterManager);
        LuaCompiler.register(env);lua("allowed=false; SAO={LeisureMusic={nativeDanceCycleAllowed=function(body,work,clip)return allowed and work=='work' end}}");
        music=(KahluaTable)((KahluaTable)env.rawget("SAO")).rawget("LeisureMusic");
        Class.forName("zombie.characters.CharacterTimedActions.LuaTimedActionNew");com.sao.agent.SAODanceCycleWeave.install();check("native_completion_hook_ready",com.sao.agent.SAODanceCycleWeave.ready());
        JAssImpImporter.Init();var skin=importClip(Path.of(args[0]).resolve("media/anims_X/Bob/Bob_Idle.x"),null);
        for(String name:List.of(SOURCE,TARGET))skin=importClip(Path.of(args[1]).resolve("anims_X/"+name+".fbx"),skin);
        check("actual_imported_two_clips",skin.animationClips.containsKey(SOURCE)&&skin.animationClips.containsKey(TARGET));
        var b=body(cell,"dancer");var other=body(cell,"other");var p=player(b,skin);var a=action(b,SOURCE);
        var sourceNode=AnimNode.Parse(Path.of(args[1]).resolve("AnimSets/player/actions/"+SOURCE+".xml").toString());
        var targetNode=AnimNode.Parse(Path.of(args[1]).resolve("AnimSets/player/actions/"+TARGET+".xml").toString());
        check("installed_native_XML",sourceNode!=null&&targetNode!=null&&sourceNode.isLooped&&targetNode.isLooped&&Math.abs(sourceNode.getSpeedScale(b)-.8)<.001);
        check("native_current_started_offslot",a.isStarted()&&b.checkCurrentAction(c->c==a)&&IsoPlayer.players[0]!=b&&b.getPlayerNum()==1);
        var t=track(p,skin.animationClips.get(SOURCE),sourceNode,true);
        loop(t);check("preadmission_no_receipt",observe(b)==null);
        check("false_guard_register_refused",!SAOBridge.INSTANCE.registerNativeDanceCycle(b,"work",a,SOURCE));env.rawset("allowed",true);
        var unstarted=new BaseAction(b);b.getCharacterActions().clear();b.getCharacterActions().add(unstarted);check("unstarted_current_action_refused",!SAOBridge.INSTANCE.registerNativeDanceCycle(b,"work",unstarted,SOURCE));b.getCharacterActions().clear();b.StartAction(a);
        check("foreign_action_refused",!SAOBridge.INSTANCE.registerNativeDanceCycle(other,"work",a,SOURCE));
        check("wrong_clip_refused",!SAOBridge.INSTANCE.registerNativeDanceCycle(b,"work",a,"Bob_Idle"));
        check("admitted",SAOBridge.INSTANCE.registerNativeDanceCycle(b,"work",a,SOURCE));
        check("no_loop_no_receipt",observe(b)==null);t.Update(.001f);check("partial_update_no_loop",observe(b)==null);
        var poseBefore=pose(t,skin);t.Update(.25f);check("actual_imported_keyframe_progress",difference(poseBefore,pose(t,skin))>.01&&observe(b)==null);
        loop(t);var row=observe(b);check("native_Update_receipt",row!=null);long first=sequence(row);
        check("exact_native_receipt",row.rawget("actorId").equals("dancer")&&row.rawget("bodyToken").equals("token:dancer")&&row.rawget("clip").equals(SOURCE)&&row.rawget("authority").equals("native-current-owned-source-animation-loop"));
        check("canonical_current",current(b,first));row.rawset("sequence",999999d);row.rawset("clip","forged");check("detached_result",sequence(observe(b))==first&&observe(b).rawget("clip").equals(SOURCE));
        env.rawset("allowed",false);check("withdrawn_read_refused",observe(b)==null);env.rawset("allowed",true);check("withdrawn_read_restore_needs_fresh_loop",observe(b)==null);loop(t);
        check("foreign_read",observe(other)==null&&!current(other,first));
        loop(t);check("new_loop_rejects_old_sequence",sequence(observe(b))>first&&!current(b,first));
        env.rawset("allowed",false);loop(t);env.rawset("allowed",true);check("withdrawn_emission_then_restored_no_receipt",observe(b)==null);loop(t);check("fresh_after_restoration",observe(b)!=null);
        var guard=music.rawget("nativeDanceCycleAllowed");lua("SAO.LeisureMusic.nativeDanceCycleAllowed=function()return true end");loop(t);music.rawset("nativeDanceCycleAllowed",guard);check("closure_replacement_restored_no_receipt",observe(b)==null);loop(t);
        var sao=(KahluaTable)env.rawget("SAO");sao.rawset("LeisureMusic",platform.newTable());loop(t);sao.rawset("LeisureMusic",music);check("table_replacement_restored_no_receipt",observe(b)==null);loop(t);
        LuaManager.thread=new KahluaThread(platform,env);loop(t);LuaManager.thread=thread;check("lua_thread_replacement_no_receipt",observe(b)==null);loop(t);
        var foreignThreadTrack=t;var worker=new Thread(()->loop(foreignThreadTrack));worker.start();worker.join();check("foreign_java_thread_no_receipt",observe(b)==null);loop(t);
        b.getModData().rawset("SAOExternalToken","replacement");loop(t);b.getModData().rawset("SAOExternalToken","token:dancer");check("token_replacement_no_receipt",observe(b)==null);loop(t);
        b.setVariable("PerformingAction",TARGET);loop(t);b.setVariable("PerformingAction",SOURCE);check("changed_action_clip_no_receipt",observe(b)==null);loop(t);
        b.getCharacterActions().clear();loop(t);b.StartAction(a);check("removed_current_action_no_receipt",observe(b)==null);loop(t);
        t.setBlendWeight(0);loop(t);t.setBlendWeight(1);check("inactive_track_no_receipt",observe(b)==null);loop(t);
        var duplicate=track(p,skin.animationClips.get(SOURCE),sourceNode,true);loop(t);p.getMultiTrack().removeTrack(duplicate);check("ambiguous_track_no_receipt",observe(b)==null);loop(t);
        b.setAsleep(true);loop(t);b.setAsleep(false);check("sleep_emission_refused",observe(b)==null);loop(t);
        zombie.network.GameClient.client=true;loop(t);zombie.network.GameClient.client=false;check("MP_client_refused",observe(b)==null);loop(t);
        zombie.network.GameServer.server=true;loop(t);zombie.network.GameServer.server=false;check("MP_server_refused",observe(b)==null);loop(t);
        expire(b);check("expired_native_receipt",observe(b)==null);loop(t);double event=((Number)observe(b).rawget("engineAtHours")).doubleValue();
        zombie.GameTime.getInstance().setTimeOfDay(zombie.GameTime.getInstance().getTimeOfDay()-1);check("backwards_native_clock_refused",observe(b)==null);zombie.GameTime.getInstance().setTimeOfDay(zombie.GameTime.getInstance().getTimeOfDay()+1);loop(t);
        var before=sequence(observe(b));p.getMultiTrack().removeTrack(t);t=track(p,skin.animationClips.get(SOURCE),sourceNode,true);check("replacement_track_needs_new_loop",observe(b)==null);loop(t);check("replacement_track_new_receipt",observe(b)!=null&&!current(b,before));
        check("foreign_work_unregister",!SAOBridge.INSTANCE.unregisterNativeDanceCycle(b,"foreign"));check("owned_unregister",SAOBridge.INSTANCE.unregisterNativeDanceCycle(b,"work"));loop(t);check("unregistered_no_receipt",observe(b)==null);
        check("target_registered",SAOBridge.INSTANCE.registerNativeDanceCycle(b,"work",a,TARGET)==false);b.setVariable("PerformingAction",TARGET);
        check("target_native_admitted",SAOBridge.INSTANCE.registerNativeDanceCycle(b,"work",a,TARGET));p.getMultiTrack().removeTrack(t);t=track(p,skin.animationClips.get(TARGET),targetNode,true);observe(b);loop(t);check("target_actual_Update_receipt",observe(b)!=null&&observe(b).rawget("clip").equals(TARGET));
        long targetSeq=sequence(observe(b));SAODanceCycle.resetRuntimeForWorld();loop(t);check("runtime_reset_rejects_replay",observe(b)==null&&!current(b,targetSeq));
        check("readmission",SAOBridge.INSTANCE.registerNativeDanceCycle(b,"work",a,TARGET));observe(b);loop(t);check("sequence_monotonic_after_reset",sequence(observe(b))>targetSeq);
        other.getModData().rawset("SAOExternalToken",null);var otherPlayer=player(other,skin);var otherAction=action(other,SOURCE);var otherTrack=track(otherPlayer,skin.animationClips.get(SOURCE),sourceNode,true);
        check("tokenless_actual_body_admitted",SAOBridge.INSTANCE.registerNativeDanceCycle(other,"work",otherAction,SOURCE));observe(other);loop(otherTrack);var tokenless=observe(other);
        check("tokenless_native_receipt_exact_nil",tokenless!=null&&tokenless.rawget("bodyToken")==null&&tokenless.rawget("actorId").equals("other")&&current(other,sequence(tokenless)));
        other.getModData().rawset("SAOExternalToken","new-token");loop(otherTrack);other.getModData().rawset("SAOExternalToken",null);check("tokenless_to_foreign_token_no_replay",observe(other)==null);
        b.setHealth(0);loop(t);check("dead_body_refused",observe(b)==null&&!current(b,targetSeq));
        System.out.println("PASS native dance cycle "+checks);System.exit(0);
    }
}
