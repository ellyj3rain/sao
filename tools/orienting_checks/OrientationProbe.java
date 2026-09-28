import com.sao.engine.*;
import com.sao.agent.SAOOrientationWeave;
import java.lang.reflect.Field;
import java.nio.file.Path;
import java.util.*;
import zombie.characters.*;
import zombie.characters.action.*;
import zombie.core.skinnedmodel.animation.*;
import zombie.core.skinnedmodel.advancedanimation.*;
import zombie.core.skinnedmodel.model.*;
import zombie.core.skinnedmodel.model.jassimp.*;
import zombie.iso.*;
import org.lwjgl.util.vector.Matrix4f;

/** Installed native animation/sound/sight owners in a method fixture; no game/render loop. */
public final class OrientationProbe {
    static int checks;
    static Field field(Class<?> type, String name) throws Exception {
        var f=type.getDeclaredField(name);f.setAccessible(true);return f;
    }
    static void check(String name, boolean value) {
        System.out.println("CHECK "+name+"="+value); if(!value)throw new AssertionError(name);checks++;
    }
    @SuppressWarnings("unchecked")
    static SkinningData skeleton(Path game) throws Exception {
        JAssImpImporter.Init();
        SkinningData data=null;
        for(String name:List.of("Bob_LookLeft","Bob_LookRight","Bob_LookDown","Bob_LookUp","Bob_Idle","Bob_Walk")) {
            var parameters=ProcessedAiSceneParams.create();
            parameters.scene=jassimp.Jassimp.importFile(game.resolve("media/anims_X/Bob/"+name+".x").toString());
            parameters.mode=JAssImpImporter.LoadMode.Normal;
            parameters.animBonesScaleModifier=1;
            parameters.skinnedTo=data;
            var imported=ImportedSkeleton.process(ImportedSkeletonParams.create(parameters,parameters.scene.getMeshes().get(0)));
            var clips=(HashMap<String,AnimationClip>)field(ImportedSkeleton.class,"clips").get(imported);
            if(data==null) data=new SkinningData(clips,
                (List<Matrix4f>)field(ImportedSkeleton.class,"bindPose").get(imported),
                (List<Matrix4f>)field(ImportedSkeleton.class,"invBindPose").get(imported),
                (List<Matrix4f>)field(ImportedSkeleton.class,"skinOffsetMatrices").get(imported),
                (List<Integer>)field(ImportedSkeleton.class,"skeletonHierarchy").get(imported),
                (HashMap<String,Integer>)field(ImportedSkeleton.class,"boneIndices").get(imported));
            else data.animationClips.putAll(clips);
        }
        check("installed_head_clips",data.animationClips.keySet().containsAll(List.of("Bob_LookLeft","Bob_LookRight","Bob_LookDown","Bob_LookUp")));
        return data;
    }
    static AnimationPlayer animation(SAOIsoPlayerShell shell,SkinningData skin) throws Exception {
        var ctor=AnimationPlayer.class.getDeclaredConstructor();ctor.setAccessible(true);
        AnimationPlayer player=ctor.newInstance();
        field(AnimationPlayer.class,"skinningData").set(player,skin);
        var bones=new AnimatorsBoneTransform[skin.numBones()]; var transforms=new Matrix4f[skin.numBones()];
        for(int i=0;i<bones.length;i++){bones[i]=AnimatorsBoneTransform.alloc();bones[i].setIdentity();transforms[i]=new Matrix4f();}
        field(AnimationPlayer.class,"boneTransforms").set(player,bones);
        field(AnimationPlayer.class,"modelTransforms").set(player,transforms);
        field(IsoGameCharacter.class,"animPlayer").set(shell,player);
        player.setTargetAndCurrentDirection(1,0);player.angleStepDelta=.5f;player.angleTwistDelta=.9f;
        return player;
    }
    static SAOIsoPlayerShell body(IsoCell cell,SkinningData skin) throws Exception {
        var desc=new SurvivorDesc(false);desc.getHumanVisual().setSkinTextureName("fixture");
        var body=new SAOIsoPlayerShell(cell,desc,10,20,0);body.setNpc(true);body.setX(10.5f);body.setY(20.5f);
        body.setCurrent(cell.getGridSquare(10,20,0));body.setForwardDirection(1,0);
        cell.getObjectList().add(body);
        animation(body,skin);
        var group=ActionGroup.getActionGroup("player");body.getActionContext().setGroup(group);
        var animator=body.getAdvancedAnimator();
        var set=new AnimationSet();set.name="player";
        for(String name:List.of("idle","movement","run","sprint")){
            AnimState state=new AnimState();state.name=name;state.set=set;
            AnimNode node=new AnimNode();node.name="native base fixture";node.animName=name.equals("idle")?"Bob_Idle":"Bob_Walk";node.parentState=state;
            node.conditions=new AnimCondition[0];state.addNode(node);set.states.put(name,state);
        }
        animator.setAnimSet(set);
        body.getActionContext().setCurrentState(group.findState("idle"));
        field(zombie.ai.StateMachine.class,"currentState").set(body.getStateMachine(),null);
        return body;
    }
    static String cue(SAOIsoPlayerShell body, int x,int y) {
        var sound=zombie.WorldSoundManager.instance.getNew();
        sound.init(null,x,y,0,30,30,0f,1f,(short)2);
        return SAOWorldSoundPulses.heard(body,sound);
    }
    static double number(se.krka.kahlua.vm.KahluaTable t,String k){return ((Number)t.rawget(k)).doubleValue();}
    static boolean active(SAOIsoPlayerShell body){return Boolean.TRUE.equals(SAOOrientation.state(body).rawget("active"));}
    static void animate(SAOIsoPlayerShell body,int frames) {
        for(int i=0;i<frames;i++) {
            body.getAdvancedAnimator().update(1f/60);
            body.getAnimationPlayer().Update(1f/60);
        }
    }
    static Matrix4f bone(SAOIsoPlayerShell body,SkinningData skin,String name) {
        return body.getAnimationPlayer().getBoneTransform(skin.boneIndices.get(name),new Matrix4f());
    }
    static double distance(Matrix4f a,Matrix4f b) {
        var x=java.nio.FloatBuffer.allocate(16);var y=java.nio.FloatBuffer.allocate(16);a.store(x);b.store(y);
        double sum=0;for(int i=0;i<16;i++)sum+=Math.abs(x.get(i)-y.get(i));return sum;
    }
    static SAOIsoPlayerShell posed(IsoCell cell,SkinningData skin,String root,float horizontal) throws Exception {
        var body=body(cell,skin);SAOOrientationAnimation.ensure(body);
        body.setVariable(SAOOrientationAnimation.ACTIVE,true);
        body.setVariable(SAOOrientationAnimation.HORIZONTAL,horizontal);
        body.setVariable(SAOOrientationAnimation.VERTICAL,0f);
        body.getAdvancedAnimator().setState(root,List.of(SAOOrientationAnimation.STATE));
        animate(body,25);return body;
    }
    static void poseChecks(IsoCell cell,SkinningData skin) throws Exception {
        for(String root:List.of("idle","movement")) {
            var left=posed(cell,skin,root,-1);var right=posed(cell,skin,root,1);
            check(root+"_native_head_pose_changes",distance(bone(left,skin,"Bip01_Head"),bone(right,skin,"Bip01_Head"))>.1);
            check(root+"_native_leg_pose_preserved",distance(bone(left,skin,"Bip01_L_Calf"),bone(right,skin,"Bip01_L_Calf"))<.0001);
            check(root+"_native_arm_pose_preserved",distance(bone(left,skin,"Bip01_L_Hand"),bone(right,skin,"Bip01_L_Hand"))<.0001);
            check(root+"_actual_head_gaze_direction",SAOSenses.gazeAngle(left)<-.9 && SAOSenses.gazeAngle(right)>.9);
            var track=right.getAnimationPlayer().getMultiTrack().getTracks().stream().filter(t->t.getClip().name.equals("Bob_LookRight")).findFirst().orElseThrow();
            check(root+"_actual_head_mask",track.getBoneWeight(skin.boneIndices.get("Bip01_Head"))==1
                && track.getBoneWeight(skin.boneIndices.get("Bip01_L_Calf"))==0);
        }
    }
    static void lifecycleChecks(IsoCell cell,SkinningData skin) throws Exception {
        var moving=body(cell,skin);moving.playerMoveDir.set(1,0);
        var path=new zombie.pathfind.Path();path.addNode(10.5f,20.5f,0);path.addNode(15.5f,20.5f,0);moving.setPath2(path);
        String token=cue(moving,10,26);check("moving_glance_admitted",SAOOrientation.request(moving,token,10,26,1,1,true));
        for(int i=0;i<40;i++)SAOOrientation.beforePostUpdate(moving);
        check("moving_route_direction_preserved",moving.playerMoveDir.x==1 && moving.playerMoveDir.y==0
            && moving.getPath2()==path && Math.abs(moving.getForwardDirectionX()-1)<.0001 && Math.abs(moving.getForwardDirectionY())<.0001);
        check("moving_head_target_changes",number(SAOOrientation.state(moving),"headHorizontal")>.5);
        var low=body(cell,skin);var high=body(cell,skin);
        check("condition_low_admitted",SAOOrientation.request(low,cue(low,10,26),10,26,.2f,.2f,true));
        check("condition_high_admitted",SAOOrientation.request(high,cue(high,10,26),10,26,1,1,true));
        for(int i=0;i<12;i++){SAOOrientation.beforePostUpdate(low);SAOOrientation.beforePostUpdate(high);}
        check("readiness_delays_response",number(SAOOrientation.state(low),"headHorizontal")==0 && number(SAOOrientation.state(high),"headHorizontal")>0);
        check("steadiness_scales_native_turn",low.getTurnDelta()<high.getTurnDelta() && low.getTurnDelta()>0);
        var table=SAOOrientation.state(high);double before=number(table,"remainingSeconds");table.rawset("remainingSeconds",99.0);
        check("inspection_detached_read_only",number(SAOOrientation.state(high),"remainingSeconds")==before);
        for(int i=0;i<200;i++)SAOOrientation.beforePostUpdate(high);
        check("native_time_expires_orientation",!active(high) && !high.getVariableBoolean(SAOOrientationAnimation.ACTIVE));
        for(String mode:List.of("action","combat","fence","window","wall","pending","sleep","dead","removed","animation")) {
            var person=body(cell,skin);String id=cue(person,10,26);
            check(mode+"_setup",SAOOrientation.request(person,id,10,26,1,1,true));
            if(mode.equals("action"))person.getCharacterActions().push(new zombie.characters.CharacterTimedActions.BaseAction(person));
            if(mode.equals("combat"))person.getECSComponent(zombie.characters.component.AIComponent.class).getHumanControlVars().aiming=true;
            if(mode.equals("fence"))field(zombie.ai.StateMachine.class,"currentState").set(person.getStateMachine(),zombie.ai.states.ClimbOverFenceState.instance());
            if(mode.equals("window"))field(zombie.ai.StateMachine.class,"currentState").set(person.getStateMachine(),zombie.ai.states.ClimbThroughWindowState.instance());
            if(mode.equals("wall"))field(zombie.ai.StateMachine.class,"currentState").set(person.getStateMachine(),zombie.ai.states.ClimbOverWallState.instance());
            if(mode.equals("pending"))person.getActionContext().reportEvent("EventClimbFence");
            if(mode.equals("sleep"))person.setAsleep(true);
            if(mode.equals("dead"))person.setHealth(0);
            if(mode.equals("removed"))person.setCurrent(null);
            if(mode.equals("animation"))field(IsoGameCharacter.class,"animPlayer").set(person,null);
            SAOOrientation.beforePostUpdate(person);
            check(mode+"_yields",!active(person) && !person.getVariableBoolean(SAOOrientationAnimation.ACTIVE));
            if(mode.equals("action"))check("timed_action_not_cancelled",person.getCharacterActions().size()==1);
            if(mode.equals("animation"))check("inspection_does_not_allocate_native_animator",!person.hasAnimationPlayer());
        }
    }
    static void postureChecks(IsoCell cell,SkinningData skin) throws Exception {
        var body=body(cell,skin);
        check("native_posture_admitted",SAOOrientation.requestPosture(body,"watch-fixture",20.5f,20.5f,1,1,.5f));
        var admitted=SAOOrientation.state(body);
        check("native_posture_identity_exposed","posture".equals(admitted.rawget("mode"))
            && "watch-fixture".equals(admitted.rawget("actionId"))
            && Math.abs(number(admitted,"requiredSeconds")-.5)<.001);
        check("different_posture_cannot_replace_active",!SAOOrientation.requestPosture(body,"cover-fixture",20.5f,20.5f,1,1,.5f));
        SAOOrientation.clearPosture(body,"cover-fixture");
        check("different_clear_cannot_cancel_posture",active(body));
        for(int i=0;i<40 && active(body);i++)SAOOrientation.beforePostUpdate(body);
        var completed=SAOOrientation.state(body);
        check("native_posture_completes_after_maintained_facing",!active(body)
            && "completed".equals(completed.rawget("reason"))
            && number(completed,"maintainedSeconds")>=.5);
        var moving=body(cell,skin);moving.playerMoveDir.set(1,0);
        check("moving_body_cannot_admit_posture",!SAOOrientation.requestPosture(moving,"moving-fixture",20.5f,20.5f,1,1,.5f));
        var cancelled=body(cell,skin);
        check("matching_clear_ends_posture",SAOOrientation.requestPosture(cancelled,"clear-fixture",20.5f,20.5f,1,1,.5f));
        SAOOrientation.clearPosture(cancelled,"clear-fixture");
        check("matching_clear_records_reason",!active(cancelled)
            && "released".equals(SAOOrientation.state(cancelled).rawget("reason")));
    }
    static void pulseChecks(IsoCell cell,SkinningData skin) throws Exception {
        var body=body(cell,skin);var other=body(cell,skin);
        var sound=zombie.WorldSoundManager.instance.getNew();sound.init(new Object(),10,26,0,30,30,0f,1f,(short)2);
        String id=SAOWorldSoundPulses.heard(body,sound);
        check("same_occurrence_stable",id.equals(SAOWorldSoundPulses.heard(body,sound)));
        check("unheard_other_body_refused",!SAOOrientation.request(other,id,10,26,1,1,true));
        check("forged_cue_position_refused",!SAOOrientation.request(body,id,11,26,1,1,true));
        check("pulse_original_admitted",SAOOrientation.request(body,id,10,26,1,1,true));SAOOrientation.clear(body);
        zombie.WorldSoundManager.instance.release(sound);
        var reused=zombie.WorldSoundManager.instance.getNew();check("native_sound_pool_reuses_object",sound==reused);
        reused.init(new Object(),10,26,0,30,30,0f,1f,(short)2);String fresh=SAOWorldSoundPulses.heard(body,reused);
        check("pooled_reinit_new_occurrence",!id.equals(fresh));
        check("pooled_reinit_can_orient",SAOOrientation.request(body,fresh,10,26,1,1,true));SAOOrientation.clear(body);
        for(int i=0;i<90;i++)cue(body,10,26);
        SAOWorldSoundPulses.heard(body,sound);
        check("heard_cache_eviction_cannot_replay",!SAOOrientation.request(body,fresh,10,26,1,1,true));
        SAOPerceptionScanner.resetRuntimeForWorld();
        check("world_reset_invalidates_cues",!SAOOrientation.request(body,fresh,10,26,1,1,true));
        check("world_reset_accepts_new_epoch",SAOOrientation.request(body,cue(body,10,26),10,26,1,1,true));
    }
    static void pureReadChecks(IsoCell cell,SkinningData skin) throws Exception {
        var body=body(cell,skin);var player=body.getAnimationPlayer();
        var unsafeField=sun.misc.Unsafe.class.getDeclaredField("theUnsafe");unsafeField.setAccessible(true);
        var unsafe=(sun.misc.Unsafe)unsafeField.get(null);
        // A real Model identity without a GPU allocation; native getter would retire this mismatch.
        Object different=unsafe.allocateInstance(Model.class);
        field(AnimationPlayer.class,"model").set(player,different);
        boolean clean;
        try { SAOOrientation.state(body); clean=field(IsoGameCharacter.class,"animPlayer").get(body)==player
            && player.getModel()==different && player.getSkinningData()==skin; }
        catch(Throwable error) { clean=false; }
        check("inspection_model_mismatch_no_mutation",clean);
    }
    static void sensesChecks(IsoCell cell,SkinningData skin) throws Exception {
        cell.getObjectList().clear();
        var right=posed(cell,skin,"idle",1);var left=posed(cell,skin,"idle",-1);
        var target=body(cell,skin);target.setX(10.5f);target.setY(26.5f);target.setCurrent(cell.getGridSquare(10,26,0));
        target.getDescriptor().setForename("GazeTarget");target.getDescriptor().setSurname("Fixture");
        check("person_recheck_actual_gaze",SAOPerceptionScanner.canSeePersonNow(right,target,16)
            && !SAOPerceptionScanner.canSeePersonNow(left,target,16));
        String rightScan=SAOPerceptionScanner.scan(right,"10,26,0");String leftScan=SAOPerceptionScanner.scan(left,"10,26,0");
        System.out.println("SIGHT_RIGHT "+rightScan);System.out.println("SIGHT_LEFT "+leftScan);
        check("scan_actual_gaze",rightScan.contains("P:GazeTarget Fixture:") && !leftScan.contains("P:GazeTarget Fixture:"));
        check("known_tile_actual_gaze",rightScan.contains("V:10:26:0") && !leftScan.contains("V:10:26:0"));
        var holder=new IsoObject(cell);holder.setSquare(target.getCurrentSquare());target.getCurrentSquare().getObjects().add(holder);
        var container=new zombie.inventory.ItemContainer("counter",target.getCurrentSquare(),holder);holder.setContainer(container);
        check("transfer_witness_actual_gaze",SAOPerceptionScanner.canWitnessWorldTransfer(right,target,container,16)
            && !SAOPerceptionScanner.canWitnessWorldTransfer(left,target,container,16));
        var world=SAOPerceptionScanner.class.getDeclaredMethod("canSeeWorldSquareNow",IsoGameCharacter.class,IsoGridSquare.class,float.class);world.setAccessible(true);
        check("world_point_actual_gaze",Boolean.TRUE.equals(world.invoke(null,right,target.getCurrentSquare(),16f))
            && Boolean.FALSE.equals(world.invoke(null,left,target.getCurrentSquare(),16f)));
        var square=cell.getGridSquare(10,24,0);square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.WallN);
        square.getProperties().set(zombie.iso.SpriteDetails.IsoFlagType.collideN);
        square.ReCalculateVisionBlocked(cell.getGridSquare(10,23,0));cell.getGridSquare(10,23,0).ReCalculateVisionBlocked(square);
        System.out.println("NATIVE_WALL="+LosUtil.lineClear(cell,10,20,0,10,26,0,false));
        System.out.println("INTERVENING_WALL_PERSON_VISIBLE="+SAOPerceptionScanner.canSeePersonNow(right,target,16));
        check("person_occluded_by_native_wall",!SAOPerceptionScanner.canSeePersonNow(right,target,16)
            && !SAOPerceptionScanner.scan(right).contains("P:GazeTarget Fixture:"));
        check("head_gaze_does_not_see_through_wall",!SAOPerceptionScanner.canWitnessWorldTransfer(right,target,container,16)
            && !SAOPerceptionScanner.scan(right,"10,26,0").contains("V:10:26:0"));
        square.getProperties().unset(zombie.iso.SpriteDetails.IsoFlagType.WallN);square.getProperties().unset(zombie.iso.SpriteDetails.IsoFlagType.collideN);
        square.ReCalculateVisionBlocked(cell.getGridSquare(10,23,0));cell.getGridSquare(10,23,0).ReCalculateVisionBlocked(square);
        var door=new zombie.iso.objects.IsoDoor(cell);door.setSquare(square);door.north=true;
        square.getObjects().add(door);square.getSpecialObjects().add(door);
        check("native_closed_door_occludes_person",!SAOPerceptionScanner.canSeePersonNow(right,target,16));
        door.setOpen(true);
        check("native_open_door_keeps_sight",SAOPerceptionScanner.canSeePersonNow(right,target,16));
        square.getObjects().remove(door);square.getSpecialObjects().remove(door);
        var window=new zombie.iso.objects.IsoWindow(cell);window.setSquare(square);
        field(zombie.iso.objects.IsoWindow.class,"north").setBoolean(window,true);
        square.getObjects().add(window);square.getSpecialObjects().add(window);
        check("native_window_keeps_sight",SAOPerceptionScanner.canSeePersonNow(right,target,16));
        square.getObjects().remove(window);square.getSpecialObjects().remove(window);
        var normal=body(cell,skin);var deaf=body(cell,skin);var hard=body(cell,skin);
        deaf.getCharacterTraits().set(zombie.scripting.objects.CharacterTrait.DEAF,true);
        hard.getCharacterTraits().set(zombie.scripting.objects.CharacterTrait.HARD_OF_HEARING,true);
        check("native_hearing_modifiers",SAOSenses.hearing(normal,false)==1 && SAOSenses.hearing(deaf,false)==0
            && Math.abs(SAOSenses.hearing(hard,false)-1f/hard.getHearDistanceModifier())<.0001);
        var sounds=zombie.WorldSoundManager.instance.soundList;sounds.clear();
        var sound=zombie.WorldSoundManager.instance.getNew();sound.init(new Object(),10,26,0,10,30,0f,1f,(short)2);sounds.add(sound);
        String heard=SAOPerceptionScanner.scan(normal);String again=SAOPerceptionScanner.scan(normal);
        check("scanner_admits_actual_pulse",heard.contains("S:10:26:") && heard.contains(":cue:") && heard.equals(again));
        check("deaf_cannot_acquire_sound",!SAOPerceptionScanner.scan(deaf).contains("S:10:26:"));
        check("hard_hearing_changes_sound_access",!SAOPerceptionScanner.scan(hard).contains("S:10:26:"));
        check("speech_uses_same_hearing_access",SAOPerceptionScanner.canConverseNow(target,normal,10)
            && !SAOPerceptionScanner.canConverseNow(target,deaf,10) && !SAOPerceptionScanner.canConverseNow(target,hard,10));
        check("radio_keeps_nonacoustic_distance",SAOPerceptionScanner.canReceiveRadioNow(hard) && !SAOPerceptionScanner.canReceiveRadioNow(deaf));
        sounds.clear();
    }
    public static void main(String[] args) throws Exception {
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);
        IsoCell cell=(IsoCell)boot.invoke(null);
        Path candidate=Path.of(args[0]);Path game=Path.of(args[1]);
        for(String name:List.of("look.xml","tags.xml","children.xml","enter.xml","exit.xml")) {
            zombie.ZomboidFileSystem.instance.activeFileMap.put("media/saoorienting/"+name,
                candidate.resolve("mod/42.20/media/SAOOrienting/"+name).toString());
        }
        SkinningData skin=skeleton(game);
        if(args.length>2 && args[2].equals("assets")){System.out.println("PASS assets");System.exit(0);}
        SAOIsoPlayerShell body=body(cell,skin);
        check("native_layer_configuration",SAOOrientationAnimation.ensure(body));
        String first=cue(body,10,26);
        check("native_pulse_weave",SAOOrientationWeave.report().equals("sound-pulses=ready"));
        check("native_pulse_token",first!=null && first.matches("[0-9a-f-]{36}-[1-9][0-9]*"));
        check("request_admitted",SAOOrientation.request(body,first,10,26,1,1,true));
        check("native_head_input_flag_off",!body.isHeadLookAround());
        check("desired_target_not_instant_gaze",Math.abs(SAOSenses.gazeAngle(body))<.001);
        for(int i=0;i<25;i++)SAOOrientation.beforePostUpdate(body);
        var state=SAOOrientation.state(body);System.out.println("STATE remaining="+state.rawget("remainingSeconds")+" head="+state.rawget("headHorizontal"));
        check("native_animation_time_advances",number(state,"remainingSeconds")<2.4);
        check("body_not_snapped_before_native_interpolation",Math.abs(body.getAnimationPlayer().getAngle())<.001);
        check("head_target_changes",Math.abs(number(state,"headHorizontal"))>.01);
        check("head_request_without_layer_cannot_change_gaze",Math.abs(SAOSenses.gazeAngle(body))<.001);
        body.getAnimationPlayer().updateForwardDirection(body);
        float before=body.getAnimationPlayer().getAngle();body.getAnimationPlayer().DoAngles(body.getAnimationTimeDelta());
        float after=body.getAnimationPlayer().getAngle();
        check("native_gradual_body_turn",after>before && after<1.0f);
        body.getActionContext().update();
        check("native_head_child_admitted",body.getActionContext().getChildStates().stream().anyMatch(s->s.getName().equals(SAOOrientationAnimation.STATE)));
        for(int i=0;i<25;i++) {
            body.getAdvancedAnimator().update(1f/60);
            body.getAnimationPlayer().Update(1f/60);
        }
        for(var track:body.getAnimationPlayer().getMultiTrack().getTracks())System.out.println("TRACK "+track.getClip().name+" weight="+track.getBlendWeight()+" layer="+(track.animLayer==null?"none":track.animLayer.getCurrentStateName()));
        check("native_head_tracks_play",Math.abs(SAOOrientationAnimation.physicalHeadOffset(body))>.2);
        Matrix4f head=body.getAnimationPlayer().getBoneTransform(skin.boneIndices.get("Bip01_Head"),new Matrix4f());
        System.out.println("HEAD "+head);
        double remaining=number(state,"remainingSeconds");
        check("duplicate_cue_refused",!SAOOrientation.request(body,first,10,26,1,1,true));
        check("duplicate_cue_does_not_extend",number(SAOOrientation.state(body),"remainingSeconds")==remaining);
        SAOOrientation.clear(body);
        check("clear_does_not_replay",!SAOOrientation.request(body,first,10,26,1,1,true));
        poseChecks(cell,skin);
        lifecycleChecks(cell,skin);
        postureChecks(cell,skin);
        pulseChecks(cell,skin);
        sensesChecks(cell,skin);
        pureReadChecks(cell,skin);
        System.out.println("PASS orientation "+checks);System.exit(0);
    }
}
