import com.sao.engine.*;
import java.nio.file.Path;
import java.nio.file.Files;
import java.util.*;
import zombie.core.skinnedmodel.advancedanimation.*;
import zombie.core.skinnedmodel.animation.*;
import zombie.core.skinnedmodel.model.*;
import zombie.core.skinnedmodel.model.jassimp.*;
import zombie.iso.IsoCell;
import zombie.characters.CharacterTimedActions.BaseAction;
import zombie.characters.CharacterTimedActions.LuaTimedActionNew;
import zombie.Lua.LuaManager;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;

/** Actual installed animator and vanilla clips; controlled native body, no rendered game loop. */
public final class RecoveryPoseProbe {
    static int checks;
    static void check(String label, boolean value) {
        System.out.println("RECOVERY_POSE " + label + "=" + value);
        if (!value) throw new AssertionError(label);
        checks++;
    }
    @SuppressWarnings("unchecked")
    static SkinningData skin(Path game) throws Exception {
        var skin = OrientationProbe.skeleton(game);
        for (String name : List.of("Bob_Awake", "Bob_Asleep", "Bob_AwakeToAsleep", "Bob_AsleepToAwake",
                "Bob_SitGround_ActionIdle", "Bob_SitGround_toActionIdle")) {
            var parameters = ProcessedAiSceneParams.create();
            parameters.scene = jassimp.Jassimp.importFile(game.resolve("media/anims_X/Bob/" + name + ".x").toString());
            parameters.mode = JAssImpImporter.LoadMode.Normal;
            parameters.animBonesScaleModifier = 1; parameters.skinnedTo = skin;
            var imported = ImportedSkeleton.process(ImportedSkeletonParams.create(parameters, parameters.scene.getMeshes().get(0)));
            skin.animationClips.putAll((HashMap<String, AnimationClip>) OrientationProbe.field(ImportedSkeleton.class, "clips").get(imported));
        }
        return skin;
    }
    static SAOIsoPlayerShell posed(IsoCell cell, SkinningData skin, Path root, String condition) throws Exception {
        var body = OrientationProbe.body(cell, skin);
        var set = body.getAdvancedAnimator().animSet;
        var state = new AnimState(); state.name = "sitonground-sitting"; state.set = set;
        for (String name : List.of("awake", "sleep", "awake_to_sleep", "awake_to_sit", "sleep_to_awake")) {
            var node = AnimNode.Parse(root.resolve("mod/42.20/media/AnimSets/player/sitonground-sitting/SAORecovery_" + name + ".xml").toString());
            if (node == null) throw new AssertionError("native recovery XML parse " + name);
            node.parentState = state; state.addNode(node);
        }
        set.states.put(state.name, state);
        body.setVariable("SitGroundAnim", "Idle"); body.setVariable("SAORecoveryGround", condition);
        body.getAdvancedAnimator().setState(state.name, List.of());
        OrientationProbe.animate(body, 45);
        return body;
    }
    static AnimationTrack track(SAOIsoPlayerShell body, String clip) {
        return body.getAnimationPlayer().getMultiTrack().getTracks().stream()
            .filter(t -> t.getClip() != null && clip.equals(t.getClip().name)).findFirst().orElseThrow();
    }
    static LiveAnimNode node(AnimationTrack track) {
        return track.animLayer.getLiveAnimNodes().stream().filter(n -> n.containsMainAnimationTrack(track)).findFirst().orElseThrow();
    }
    static SAOIsoPlayerShell seatedWithVanillaAction(IsoCell cell, SkinningData skin, Path root, Path game) throws Exception {
        var body = posed(cell, skin, root, "Awake");
        var set = body.getAdvancedAnimator().animSet;
        var sitting = set.states.get("sitonground-sitting");
        var actionNode = AnimNode.Parse(game.resolve("media/AnimSets/player/sitonground-sitting/sit_action.xml").toString());
        actionNode.parentState = sitting; sitting.addNode(actionNode);
        // Native waitToStart resolves the root sitonground state, then inspects
        // active root-layer nodes. Keep the child node's authentic parent identity.
        var ground = new AnimState(); ground.name = "sitonground"; ground.set = set;
        ground.addNode(actionNode); set.states.put(ground.name, ground);
        OrientationProbe.field(zombie.ai.StateMachine.class, "currentState")
            .set(body.getStateMachine(), zombie.ai.states.PlayerSitOnGroundState.instance());
        body.setSitOnGround(true); body.setVariable("SitGroundStarted", true);
        return body;
    }
    static void nativeStartInterlock(IsoCell cell, SkinningData skin, Path root, Path game) throws Exception {
        var body = seatedWithVanillaAction(cell, skin, root, game);
        var action = new BaseAction(body);
        body.StartAction(action);
        // The controlled animator has no body update. Supply the same public
        // variable that the inherited update derives from this native queue.
        body.setVariable("hasTimedActions", !body.getCharacterActions().isEmpty());
        for (int i = 0; i < 180; i++) { OrientationProbe.animate(body, 1); action.waitToStart(); }
        check("awake_pose_keeps_native_action_waiting", !action.isStarted()
            && body.shouldWaitToStartTimedAction() && SAORecoveryPose.isRecoveryPose(body, "rest"));
        body.clearVariable("SAORecoveryGround");
        for (int i = 0; i < 180 && !action.isStarted(); i++) {
            OrientationProbe.animate(body, 1); action.waitToStart();
        }
        check("release_pose_allows_native_action_start", action.isStarted() && !body.shouldWaitToStartTimedAction());
        check("native_start_does_not_grant_sleep", !body.isAsleep() && !SAORecoveryPose.isRecoveryPose(body, "sleep"));
    }
    static void lua(KahluaThread thread, KahluaTable env, String source, String name) throws Exception {
        thread.call(LuaCompiler.loadstring(source, name, env), null, null, null);
    }
    static void ownedTransition(IsoCell cell, SkinningData skin, Path root, Path game, Path pose, Path actionFile, boolean omitEvent) throws Exception {
        var body = seatedWithVanillaAction(cell, skin, root, game);
        if (omitEvent) {
            for (var node : body.getAdvancedAnimator().animSet.states.get("sitonground-sitting").nodes)
                node.events.removeIf(event -> "AsleepEvent".equals(event.eventName));
        }
        BaseAction preceding = null;
        if (!omitEvent) {
            preceding = new BaseAction(body); preceding.maxTime = 5;
            body.StartAction(preceding); body.setVariable("hasTimedActions", true);
        }
        var platform = new J2SEPlatform(); var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env); thread.debugOwnerThread = Thread.currentThread();
        LuaManager.platform = platform; LuaManager.env = env; LuaManager.thread = thread;
        LuaManager.converterManager = new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller = new LuaCaller(LuaManager.converterManager);
        var exposer = new LuaManager.Exposer(LuaManager.converterManager, platform, env);
        Class<?>[] types = {com.sao.bridge.SAOBridge.class, SAOIsoPlayerShell.class,
            zombie.characters.IsoPlayer.class, zombie.characters.IsoGameCharacter.class,
            BaseAction.class, LuaTimedActionNew.class};
        for (var type : types) exposer.setExposed(type);
        for (var type : types) exposer.exposeLikeJava(type, env);
        zombie.Lua.LuaEventManager.register(platform, env);
        env.rawset("__body", body); env.rawset("SAOJavaBridge", com.sao.bridge.SAOBridge.INSTANCE);
        body.getModData().rawset("SAOPersonId","runner");
        lua(thread, env, "require=function()end; isClient=function()return false end; isServer=function()return false end", "fixture-prelude");
        for (var path : List.of(game.resolve("media/lua/shared/ISBaseObject.lua"),
                game.resolve("media/lua/shared/TimedActions/ISBaseTimedAction.lua"), pose, actionFile))
            lua(thread, env, Files.readString(path), path.toString());
        lua(thread,env,"ISRestAction={};getActivatedMods=function()return {contains=function(_,id)return id=='LeanAndLie' or id=='TchernoLib' end}end","installed-mod-list");
        lua(thread,env,"TchAL={stateVariableOnGround='SleepStateOnGround'};getActivatedMods=function()error('external activation queried')end","foreign-source-trap");
        lua(thread,env,"__packagedAvailable=SAO.RecoveryPose.available()","owned-source-availability");
        check("owned_source_available_without_external_activation_" + omitEvent, Boolean.TRUE.equals(env.rawget("__packagedAvailable")));
        env.rawset("__enqueue", (JavaFunction)(frame, count) -> {
            var table = (KahluaTable)frame.get(0); var action = new LuaTimedActionNew(table, body);
            table.rawset("action", action);
            if (body.getCharacterActions().isEmpty()) body.StartAction(action);
            body.setVariable("hasTimedActions", true); frame.push(true); return 1;
        });
        lua(thread, env, """
            __rec={id='runner'}; __owned=true; __queued=nil; __hours=12
            SAO.Identity={get=function()return __rec end}
            SAO.History={countyHours=function()return __hours end}
            SAO.Needs={ownsRecoveryBody=function()return __owned end,
                queueVerified=function(action) __queued=action; return __enqueue(action) end}
            local q={onCompleted=function(_,action) if __queued==action then __queued=nil end end}
            ISTimedActionQueue={queues={},hasAction=function(action)return action~=nil and __queued==action end,
                getTimedActionQueue=function()return q end}
            ISLogSystem={logAction=function()end}
            SAO.RecoveryPose.storeAppliedOffset(__body,.4,0)
            __owned=false
            __work={body=__body,custody=SAO.RecoveryPose.captureCustody(__body),kind='sleep',id='runner',rec=__rec,requestedAt=12,
                phase='lying-awake',finished=true}
            __staleStatus=SAO.RecoveryPose.poll(__work)
            """, "stale-transition");
        check("stale_owner_cannot_release_pose_" + omitEvent, "failed".equals(env.rawget("__staleStatus"))
            && "Awake".equals(body.getVariableString("SAORecoveryGround")) && env.rawget("__queued") == null);
        lua(thread, env, """
            __owned=true
            __work={body=__body,custody=SAO.RecoveryPose.captureCustody(__body),kind='sleep',id='runner',rec=__rec,requestedAt=12,
                phase='lying-awake',finished=true}
            __status=SAO.RecoveryPose.poll(__work)
            """, "owned-transition");
        var work = (KahluaTable)env.rawget("__work");
        var action = (LuaTimedActionNew)((KahluaTable)work.rawget("action")).rawget("action");
        for (int i = 0; i < 180 && !action.isStarted(); i++) {
            OrientationProbe.animate(body, 1);
            if (preceding != null && body.getCharacterActions().contains(preceding)) {
                if (!preceding.isStarted()) preceding.waitToStart();
                else preceding.update();
                if (preceding.finished()) {
                    preceding.perform(); body.getCharacterActions().remove(preceding); body.StartAction(action);
                }
            } else action.waitToStart();
        }
        check("owned_transition_starts_through_native_wait", action.isStarted()
            && Boolean.TRUE.equals(work.rawget("started")) && "AwakeToAsleep".equals(body.getVariableString("SAORecoveryGround")));
        check("owned_transition_start_grants_no_sleep", !body.isAsleep() && work.rawget("sleepEvent") == null);
        if (preceding != null) check("incidental_native_action_finishes_before_owned_transition",
            preceding.isStarted() && preceding.finished() && !body.getCharacterActions().contains(preceding));
        int completionFrame = -1;
        for (int i = 0; i < 360; i++) {
            OrientationProbe.animate(body, 1);
            if (completionFrame < 0) {
                action.update();
                if (action.finished() || action.isForceComplete()) {
                    completionFrame = i; action.complete(); action.perform(); body.getCharacterActions().remove(action);
                    body.setVariable("hasTimedActions", false);
                }
            }
        }
        System.out.println("TRANSITION completionFrame=" + completionFrame + " time=" + action.getCurrentTime()
            + " event=" + work.rawget("sleepEvent") + " clipDuration=" + skin.animationClips.get("Bob_AwakeToAsleep").getDuration());
        if (omitEvent) {
            check("missing_native_event_cannot_finish_or_sleep", completionFrame < 0 && work.rawget("sleepEvent") == null
                && !Boolean.TRUE.equals(work.rawget("finished")) && !body.isAsleep());
            lua(thread, env, "__hours=12.26; __status=SAO.RecoveryPose.poll(__work)", "missing-event-timeout");
            check("missing_native_event_has_bounded_preparation", "failed".equals(env.rawget("__status")));
            return;
        }
        check("native_clip_delivers_sleep_event_before_completion", Boolean.TRUE.equals(work.rawget("sleepEvent")));
        lua(thread, env, "__status=SAO.RecoveryPose.poll(__work); __offset=SAO.RecoveryPose.getAppliedOffset(__body)", "transition-result");
        check("completed_native_transition_is_admitted", "admitted".equals(env.rawget("__status"))
            && Boolean.TRUE.equals(work.rawget("finished")) && SAORecoveryPose.isRecoveryPose(body, "sleep"));
        check("handoff_preserves_offset_without_physiology", Double.valueOf(.4).equals(env.rawget("__offset")) && !body.isAsleep());
    }
    static void installedOriginalCoexistence(IsoCell cell, SkinningData skin, Path root) throws Exception {
        var body=posed(cell,skin,root,"Awake");
        var state=body.getAdvancedAnimator().animSet.states.get("sitonground-sitting");
        for(String file:List.of("sit_loop_Awake","sit_loop_Sleep","sit_loop_AwakeToAsleep","sit_loop_AwakeToSit")) {
            var parsed=AnimNode.Parse(externalRoot().resolve("media/AnimSets/player/sitonground-sitting/"+file+".xml").toString());
            if(parsed==null)throw new AssertionError("original installed node parse "+file);
            parsed.parentState=state;state.addNode(parsed);
        }
        body.clearVariable("SleepStateOnGround");OrientationProbe.animate(body,90);
        check("owned_pose_with_original_nodes_present",SAORecoveryPose.isRecoveryPose(body,"rest"));
        body.clearVariable("SAORecoveryGround");body.setVariable("SleepStateOnGround","Awake");OrientationProbe.animate(body,90);
        check("original_foreign_pose_not_owned", !SAORecoveryPose.isRecoveryPose(body,"rest") && node(track(body,"Bob_Awake")).getSourceNode().name.equals("sit_loop_Awake"));
        body.clearVariable("SleepStateOnGround");body.setVariable("SAORecoveryGround","Awake");OrientationProbe.animate(body,90);
        check("owned_pose_restored_after_foreign_pose",SAORecoveryPose.isRecoveryPose(body,"rest"));
    }
    public static void main(String[] args) throws Exception {
        var boot = MovementCrossingProbe.class.getDeclaredMethod("boot"); boot.setAccessible(true);
        var cell = (IsoCell) boot.invoke(null);
        var root = Path.of(args[0]); var skin = skin(Path.of(args[1]));
        var awake = posed(cell, skin, root, "Awake"); var asleep = posed(cell, skin, root, "Asleep");
        check("actual_awake", SAORecoveryPose.isRecoveryPose(awake, "rest"));
        check("actual_asleep", SAORecoveryPose.isRecoveryPose(asleep, "sleep"));
        check("distinct_kind", !SAORecoveryPose.isRecoveryPose(awake, "sleep") && !SAORecoveryPose.isRecoveryPose(asleep, "rest"));
        check("unknown_kind", !SAORecoveryPose.isRecoveryPose(awake, "awakeRest"));
        check("null_body", !SAORecoveryPose.isRecoveryPose(null, "sleep"));
        var standing = OrientationProbe.body(cell, skin); standing.setAsleep(true);
        standing.setVariable("SAORecoveryGround", "Asleep"); OrientationProbe.animate(standing, 45);
        check("flag_and_variable_not_pose", !SAORecoveryPose.isRecoveryPose(standing, "sleep"));
        check("actual_body_not_other", !SAORecoveryPose.isRecoveryPose(standing, "rest"));
        check("transition_not_completion", !SAORecoveryPose.isRecoveryPose(posed(cell, skin, root, "AwakeToAsleep"), "sleep"));
        check("same_clip_wrong_node", !SAORecoveryPose.isRecoveryPose(posed(cell, skin, root, "AwakeToSit"), "rest"));
        var track = track(asleep, "Bob_Asleep"); var node = node(track);
        float weight = track.getBlendWeight();
        for (float invalid : new float[]{0, -1, Float.NaN, Float.POSITIVE_INFINITY}) {
            track.setBlendWeight(invalid);
            check("track_weight_" + invalid, !SAORecoveryPose.isRecoveryPose(asleep, "sleep"));
        }
        track.setBlendWeight(weight); node.setWeightsToZero();
        check("zero_node_weight", !SAORecoveryPose.isRecoveryPose(asleep, "sleep"));
        node.setWeightsToFull(); node.setActive(false);
        check("fading_node_not_active", !SAORecoveryPose.isRecoveryPose(asleep, "sleep"));
        node.setActive(true);
        var source = node.getSourceNode(); String parent = source.parentState.name;
        source.parentState.name = "idle";
        check("wrong_parent", !SAORecoveryPose.isRecoveryPose(asleep, "sleep"));
        source.parentState.name = parent;
        String name = source.name; source.name = "other_sleep";
        check("wrong_node", !SAORecoveryPose.isRecoveryPose(asleep, "sleep")); source.name = name;
        check("observation_restored", SAORecoveryPose.isRecoveryPose(asleep, "sleep"));
        OrientationProbe.field(zombie.characters.IsoGameCharacter.class, "animPlayer").set(standing, null);
        check("missing_player", !SAORecoveryPose.isRecoveryPose(standing, "sleep"));
        check("read_does_not_allocate", !standing.hasAnimationPlayer());
        installedOriginalCoexistence(cell, skin, root);
        nativeStartInterlock(cell, skin, root, Path.of(args[1]));
        var pose = args.length > 2 ? Path.of(args[2]) : root.resolve("mod/42.20/media/lua/client/SAO_RecoveryPose.lua");
        var actionFile = args.length > 3 ? Path.of(args[3]) : root.resolve("mod/42.20/media/lua/shared/TimedActions/SAORecoveryTransitionAction.lua");
        ownedTransition(cell, skin, root, Path.of(args[1]), pose, actionFile, false);
        ownedTransition(cell, skin, root, Path.of(args[1]), pose, actionFile, true);
        System.out.println("PASS recovery pose " + checks); System.exit(0);
    }
    static Path externalRoot() {
        return Path.of(System.getProperty("sao.test.recoveryExternalRoot", "C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3652012357/mods/LeanAndLie/common"));
    }
}
