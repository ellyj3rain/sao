import com.sao.engine.*;
import com.sao.agent.SAODanceCycleWeave;
import com.sao.bridge.SAOBridge;
import java.nio.file.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.integration.LuaCaller;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import zombie.Lua.LuaManager;
import zombie.characters.CharacterTimedActions.*;
import zombie.core.skinnedmodel.animation.*;
import zombie.core.skinnedmodel.model.SkinningData;
import zombie.core.skinnedmodel.advancedanimation.AnimNode;
import zombie.iso.*;

/** Original native perform transition and finally scope; no fabricated loop receipt. */
public final class DanceCompletionProbe {
    static int checks,failures;static SAOIsoPlayerShell body,foreign;static AnimationPlayer player;static SkinningData skin;static AnimNode node;
    static java.util.function.Consumer<LuaTimedActionNew> callback;static LuaTimedActionNew executing;
    public static boolean hardwareFault;
    public static final class NativeFault {
        @net.bytebuddy.asm.Advice.OnMethodEnter
        public static void enter(){if(hardwareFault)throw new IllegalStateException("controlled-native-perform-hardware-fault");}
    }
    static void check(String name,boolean value){System.out.println("DANCE_COMPLETION:"+name+"="+value);if(!value){failures++;throw new AssertionError("DANCE_COMPLETION:"+name);}checks++;}
    static KahluaTable row(){return (KahluaTable)SAOBridge.INSTANCE.observeNativeDanceCycle(body,"work");}
    static boolean completion(long seq){return SAOBridge.INSTANCE.nativeDanceCycleCompletionCurrent(body,"work",seq);}
    static LuaTimedActionNew action(SAOIsoPlayerShell actor)throws Exception{
        var env=DanceCycleProbe.env;var table=LuaManager.platform.newTable();table.rawset("Type","native-dance-transition-fixture");table.rawset("character",actor);table.rawset("maxTime",-1d);
        table.rawset("waitToStart",LuaCompiler.loadstring("return function()return false end","wait",env));
        table.rawset("valid",DanceCycleProbe.thread.call(LuaCompiler.loadstring("return function()return true end","valid",env),null,null,null));
        table.rawset("waitToStart",DanceCycleProbe.thread.call((LuaClosure)table.rawget("waitToStart"),null,null,null));
        for(String name:List.of("start","update","complete"))table.rawset(name,(JavaFunction)(f,n)->0);
        var classTable=LuaManager.platform.newTable();classTable.rawset("complete",table.rawget("complete"));table.setMetatable(classTable);
        table.rawset("perform",(JavaFunction)(f,n)->{if(callback!=null)callback.accept(executing);return 0;});
        table.rawset("stop",(JavaFunction)(f,n)->0);
        actor.getCharacterActions().clear();actor.clearVariable("PerformingAction");var action=new LuaTimedActionNew(table,actor);table.rawset("action",action);actor.StartAction(action);action.waitToStart();action.setActionAnim(DanceCycleProbe.SOURCE);return action;
    }
    record Prepared(LuaTimedActionNew action,long sequence){}
    static Prepared prepare(boolean emit)throws Exception{
        SAOBridge.INSTANCE.unregisterNativeDanceCycle(body,"work");DanceCycleProbe.env.rawset("allowed",true);callback=null;
        var action=action(body);player.getMultiTrack().reset();var track=DanceCycleProbe.track(player,skin.animationClips.get(DanceCycleProbe.SOURCE),node,true);
        check("native_started_transition_action",action.isStarted()&&body.checkCurrentAction(a->a==action));
        check("native_transition_registered",SAOBridge.INSTANCE.registerNativeDanceCycle(body,"work",action,DanceCycleProbe.SOURCE));row();
        if(emit){DanceCycleProbe.loop(track);var row=row();check("actual_Update_transition_receipt",row!=null);return new Prepared(action,DanceCycleProbe.sequence(row));}
        return new Prepared(action,0);
    }
    static void perform(LuaTimedActionNew action){executing=action;action.forceComplete();action.perform();executing=null;}
    public static void main(String[] args)throws Exception{
        Thread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);var cell=(IsoCell)boot.invoke(null);
        var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);thread.debugOwnerThread=Thread.currentThread();
        LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;LuaManager.converterManager=new KahluaConverterManager();zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);LuaManager.caller=new LuaCaller(LuaManager.converterManager);
        DanceCycleProbe.env=env;DanceCycleProbe.thread=thread;LuaCompiler.register(env);DanceCycleProbe.lua("allowed=true;SAO={LeisureMusic={nativeDanceCycleAllowed=function(body,work,clip)return allowed and work=='work' end}}");
        var instrumentation=net.bytebuddy.agent.ByteBuddyAgent.install();Class.forName("zombie.characters.CharacterTimedActions.LuaTimedActionNew");
        new net.bytebuddy.agent.builder.AgentBuilder.Default().disableClassFormatChanges().with(net.bytebuddy.agent.builder.AgentBuilder.RedefinitionStrategy.RETRANSFORMATION)
            .type(net.bytebuddy.matcher.ElementMatchers.named("zombie.characters.CharacterTimedActions.BaseAction"))
            .transform((builder,type,loader,module,domain)->builder.visit(net.bytebuddy.asm.Advice.to(NativeFault.class).on(net.bytebuddy.matcher.ElementMatchers.named("perform").and(net.bytebuddy.matcher.ElementMatchers.takesArguments(0))))).installOn(instrumentation);
        zombie.core.skinnedmodel.model.jassimp.JAssImpImporter.Init();skin=DanceCycleProbe.importClip(Path.of(args[0]).resolve("media/anims_X/Bob/Bob_Idle.x"),null);skin=DanceCycleProbe.importClip(Path.of(args[1]).resolve("anims_X/"+DanceCycleProbe.SOURCE+".fbx"),skin);
        body=DanceCycleProbe.body(cell,"terminal");body.getModData().rawset("SAOExternalToken",null);foreign=DanceCycleProbe.body(cell,"foreign");player=DanceCycleProbe.player(body,skin);
        node=AnimNode.Parse(Path.of(args[1]).resolve("AnimSets/player/actions/"+DanceCycleProbe.SOURCE+".xml").toString());
        var initialAction=action(body);check("missing_native_hook_registration_refused",!SAOBridge.INSTANCE.registerNativeDanceCycle(body,"work",initialAction,DanceCycleProbe.SOURCE));
        SAODanceCycleWeave.install(instrumentation);check("actual_native_perform_weave_ready",SAODanceCycleWeave.ready());
        var real=prepare(true);check("outside_scope_refused",!completion(real.sequence));
        callback=a->{check("original_BaseAction_cleared_animation",!DanceCycleProbe.SOURCE.equals(body.getVariableString("PerformingAction")));
            check("live_guard_preserved_refusal",!SAOBridge.INSTANCE.nativeDanceCycleCurrent(body,"work",real.sequence));check("exact_native_completion_witness",completion(real.sequence));
            check("foreign_completion_body_refused",!SAOBridge.INSTANCE.nativeDanceCycleCompletionCurrent(foreign,"work",real.sequence));
            check("foreign_completion_work_sequence_refused",!SAOBridge.INSTANCE.nativeDanceCycleCompletionCurrent(body,"foreign",real.sequence)&&!completion(real.sequence+1));};
        perform(real.action);check("successful_finally_scope_cleared",!completion(real.sequence));
        var noLoop=prepare(false);callback=a->check("native_without_loop_refused",!completion(noLoop.sequence));perform(noLoop.action);check("no_loop_finally_scope_cleared",!completion(noLoop.sequence));
        var withdrawn=prepare(true);env.rawset("allowed",false);callback=a->{env.rawset("allowed",true);check("withdrawn_entry_restored_no_witness",!completion(withdrawn.sequence));};perform(withdrawn.action);check("withdrawn_entry_finally_cleared",!completion(withdrawn.sequence));
        var live=prepare(true);callback=a->{env.rawset("allowed",false);check("withdrawn_inside_native_scope_refused",!completion(live.sequence));env.rawset("allowed",true);};perform(live.action);check("withdrawn_inside_finally_cleared",!completion(live.sequence));
        var replaced=prepare(true);var otherAction=action(foreign);callback=a->check("foreign_native_action_scope_refused",!completion(replaced.sequence));perform(otherAction);check("foreign_native_scope_finally_cleared",!completion(replaced.sequence));
        var parent=prepare(true);var nestedAction=action(foreign);callback=a->{
            check("native_parent_scope_entered",completion(parent.sequence));var parentCallback=callback;
            callback=nested->check("nested_foreign_action_scope_refused",!completion(parent.sequence));perform(nestedAction);callback=parentCallback;
            check("native_parent_scope_restored",completion(parent.sequence));};perform(parent.action);check("nested_parent_finally_cleared",!completion(parent.sequence));
        var sourceFault=prepare(true);callback=a->{check("source_fault_entered_real_scope",completion(sourceFault.sequence));throw new IllegalStateException("controlled-source-perform-fault");};perform(sourceFault.action);check("original_Lua_pcall_fault_finally_cleared",!completion(sourceFault.sequence));
        var nativeFault=prepare(true);hardwareFault=true;boolean fault=false;try{perform(nativeFault.action);}catch(IllegalStateException expected){fault=expected.getMessage().contains("controlled-native-perform-hardware-fault");}finally{hardwareFault=false;executing=null;}
        check("native_hardware_fault_propagated",fault);check("native_throw_finally_scope_cleared",!completion(nativeFault.sequence));
        var retired=prepare(true);callback=a->{SAOBridge.INSTANCE.unregisterNativeDanceCycle(body,"work");check("retired_binding_inside_scope_refused",!completion(retired.sequence));};perform(retired.action);check("retired_finally_scope_cleared",!completion(retired.sequence));
        check("no_swallowed_native_callback_failures",failures==0);System.out.println("PASS native dance completion "+checks);System.exit(0);
    }
}
