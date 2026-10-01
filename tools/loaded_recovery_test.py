"""Production recovery priority and installed native physiology; no rendered world.

Controlled private memory/permission and scheduling surround actual owned native
body receivers. The installed calculateStats method supplies every stat change.
Mutation controls restore the original work cutoff and false recovery credit.
"""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

import flee_continuity_test as fixture

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "_scratch/c109-loaded-recovery/checks"

JAVA = r'''
import com.sao.engine.SAOIsoPlayerShell;
import com.sao.engine.SAONeeds;
import com.sao.bridge.SAOBridge;
import java.nio.file.*;
import java.lang.reflect.*;
import java.util.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.converter.KahluaConverterManager;
import se.krka.kahlua.integration.LuaCaller;
import zombie.Lua.LuaManager;
import zombie.characters.*;
import zombie.iso.*;
public final class LoadedRecoveryProbe {
    static void check(String name, boolean pass) {
        System.out.println("NATIVE " + name + "=" + pass);
        if (!pass) throw new AssertionError(name);
    }
    public static void main(String[] args) throws Exception {
        var boot=MovementCrossingProbe.class.getDeclaredMethod("boot");boot.setAccessible(true);
        var cell=(IsoCell)boot.invoke(null);
        var regions=zombie.iso.areas.isoregion.IsoRegions.class.getDeclaredField("dataRoot");
        regions.setAccessible(true);regions.set(null,new zombie.iso.areas.isoregion.data.DataRoot());
        var create=MovementCrossingProbe.class.getDeclaredMethod("person",IsoCell.class);create.setAccessible(true);
        var body=(SAOIsoPlayerShell)create.invoke(null,cell);
        var host=(SAOIsoPlayerShell)create.invoke(null,cell);
        body.setNpc(true);body.remote=false;body.playerIndex=99;host.playerIndex=0;
        body.getModData().rawset("SAOPersonId","runner");
        body.setSquare(body.getCurrentSquare());body.getCurrentSquare().getMovingObjects().add(body);
        cell.getObjectList().add(body);
        IsoPlayer.players[0]=host;IsoPlayer.setInstance(host);
        var state=zombie.ai.StateMachine.class.getDeclaredField("currentState");state.setAccessible(true);
        state.set(body.getStateMachine(),zombie.ai.states.IdleState.instance());
        var platform=new J2SEPlatform();var env=platform.newEnvironment();var thread=new KahluaThread(platform,env);
        thread.debugOwnerThread=Thread.currentThread();LuaManager.platform=platform;LuaManager.env=env;LuaManager.thread=thread;
        LuaManager.converterManager=new KahluaConverterManager();
        zombie.Lua.KahluaNumberConverter.install(LuaManager.converterManager);
        LuaManager.caller=new LuaCaller(LuaManager.converterManager);
        var exposer=new LuaManager.Exposer(LuaManager.converterManager,platform,env);
        Class<?>[] types={SAOBridge.class,SAOIsoPlayerShell.class,IsoPlayer.class,IsoGameCharacter.class,
            Stats.class,CharacterStat.class,zombie.scripting.objects.CharacterTrait.class,
            zombie.characters.traits.CharacterTraits.class,IsoCell.class,IsoGridSquare.class,
            zombie.inventory.ItemContainer.class,zombie.util.list.PZArrayList.class,ArrayList.class};
        for(var type:types)exposer.setExposed(type);
        for(var type:types)exposer.exposeLikeJava(type,env);
        zombie.Lua.LuaEventManager.register(platform,env);
        var game=Path.of(args[0]);
        thread.call(LuaCompiler.loadstring(Files.readString(game.resolve("media/lua/shared/defines.lua")),"defines",env),null,null,null);
        zombie.ZomboidGlobals.Load();
        zombie.GameTime.getInstance().setMinutesPerDay(60);
        zombie.GameTime.getInstance().setMultiplier(5);
        var calculate=IsoPlayer.class.getDeclaredMethod("calculateStats");calculate.setAccessible(true);
        var endurance=IsoPlayer.class.getDeclaredMethod("updateEndurance");endurance.setAccessible(true);
        var wake=IsoGameCharacter.class.getDeclaredMethod("updateStats_WakeState");wake.setAccessible(true);
        var sleeping=IsoPlayer.class.getDeclaredMethod("updateStats_Sleeping");sleeping.setAccessible(true);
        var stats=body.getStats();stats.set(CharacterStat.FATIGUE,.9f);stats.set(CharacterStat.HUNGER,.2f);
        stats.set(CharacterStat.THIRST,.1f);stats.set(CharacterStat.ENDURANCE,.3f);
        SAONeeds.setShellAsleep(body,true);check("real_native_sleep_admitted",body.isAsleep());
        // Let the native event's delay elapse through native sleep ticks; no
        // fatigue or delay value is rewritten to manufacture admission.
        IsoPlayer.setInstance(body);for(int i=0;i<2000;i++)wake.invoke(body);
        IsoPlayer.setInstance(host);
        float before=stats.get(CharacterStat.FATIGUE);
        wake.invoke(body);check("off_singleton_dispatch_is_inert",stats.get(CharacterStat.FATIGUE)==before);
        IsoPlayer.setInstance(body);wake.invoke(body);
        check("native_singleton_sleep_recovers",stats.get(CharacterStat.FATIGUE)<before);
        float measured=stats.get(CharacterStat.FATIGUE), energy=stats.get(CharacterStat.ENDURANCE);
        SAONeeds.restRecoverTick(body,8);
        check("controller_elapsed_time_grants_no_credit",stats.get(CharacterStat.FATIGUE)==measured
            && stats.get(CharacterStat.ENDURANCE)==energy);
        // Compare one normal inherited dispatch with exactly one native sleep
        // invocation. No extra physiology call is inserted in the shell update.
        stats.set(CharacterStat.FATIGUE,.9f);wake.invoke(body);float one=stats.get(CharacterStat.FATIGUE);
        stats.set(CharacterStat.FATIGUE,.9f);sleeping.invoke(body);
        check("inherited_dispatch_exactly_one_sleep_step",Math.abs(one-stats.get(CharacterStat.FATIGUE))<1e-7f);
        float floorDelta=.9f-one;body.setBedType("goodBed");stats.set(CharacterStat.FATIGUE,.9f);wake.invoke(body);
        check("native_bed_quality_changes_recovery",.9f-stats.get(CharacterStat.FATIGUE)>floorDelta);
        body.setBedType("floor");body.getCharacterTraits().set(zombie.scripting.objects.CharacterTrait.INSOMNIAC,true);
        stats.set(CharacterStat.FATIGUE,.9f);wake.invoke(body);
        check("native_insomnia_changes_recovery",.9f-stats.get(CharacterStat.FATIGUE)<floorDelta);
        body.getCharacterTraits().set(zombie.scripting.objects.CharacterTrait.INSOMNIAC,false);
        zombie.GameTime.getInstance().setMultiplier(1);stats.set(CharacterStat.FATIGUE,.9f);wake.invoke(body);
        check("native_time_multiplier_changes_recovery",.9f-stats.get(CharacterStat.FATIGUE)<floorDelta);
        zombie.GameTime.getInstance().setMultiplier(5);
        float hunger=stats.get(CharacterStat.HUNGER);wake.invoke(body);
        check("sleep_does_not_suppress_hunger",stats.get(CharacterStat.HUNGER)>hunger);
        SAONeeds.setShellAsleep(body,false);before=stats.get(CharacterStat.FATIGUE);hunger=stats.get(CharacterStat.HUNGER);
        wake.invoke(body);check("awake_needs_still_accrue",stats.get(CharacterStat.FATIGUE)>before
            && stats.get(CharacterStat.HUNGER)>hunger);
        var tick=(JavaFunction)(frame,count)->{
            int n=((Number)frame.get(0)).intValue();long start=System.nanoTime();
            try{for(int i=0;i<n;i++){endurance.invoke(body);calculate.invoke(body);}}
            catch(Exception error){throw new IllegalStateException(error);}
            System.out.println("CADENCE "+n+" native stat-owner pairs: "+(System.nanoTime()-start)/1e6+" ms");
            frame.push((System.nanoTime()-start)/1e6);return 1;
        };
        env.rawset("__nativeTicks",tick);env.rawset("__body",body);env.rawset("__bridge",SAOBridge.INSTANCE);
        env.rawset("__host",host);
        env.rawset("__reloadNeeds",(JavaFunction)(frame,count)->{
            try{thread.call(LuaCompiler.loadstring(Files.readString(Path.of((String)frame.get(0))),"reloaded-needs",env),null,null,null);}
            catch(Exception failure){throw new IllegalStateException(failure);}return 0;
        });
        env.rawset("__pressureNative",(JavaFunction)(frame,count)->{
            stats.set(CharacterStat.HUNGER,((Number)frame.get(0)).floatValue());
            stats.set(CharacterStat.THIRST,((Number)frame.get(1)).floatValue());
            frame.push(true);return 1;
        });
        env.rawset("__resetNative",(JavaFunction)(frame,count)->{
            SAONeeds.setShellAsleep(body,false);body.setIsResting(false);body.setSitOnGround(false);
            stats.set(CharacterStat.FATIGUE,((Number)frame.get(0)).floatValue());
            stats.set(CharacterStat.ENDURANCE,((Number)frame.get(1)).floatValue());
            stats.set(CharacterStat.HUNGER,((Number)frame.get(2)).floatValue());
            stats.set(CharacterStat.THIRST,((Number)frame.get(3)).floatValue());
            IsoPlayer.setInstance(body);frame.push(true);return 1;
        });
        for(int i=1;i<args.length;i++){
            System.out.println("LOAD "+Path.of(args[i]).getFileName());
            thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[i])),args[i],env),null,null,null);
        }
        Object result=env.rawget("__result");System.out.println("VALUE "+result);
        if(!String.valueOf(result).startsWith("PASS "))throw new AssertionError(result);
    }
}
'''

LUA = r'''
local checks=0
local function check(name,value)
 if not value then error("RECOVERY:"..name) end
 checks=checks+1
end
local b=__body
local rec={id="runner",homeX=10,homeY=20,homeZ=0}
local a={rec=rec,state="IDLE"}
local hours,permission,claim,seatArgs=12,true,true,false
local actualThreatCount=SAO.Perception.believedThreatCount
SAOJavaBridge=__bridge
SAO.Body.active={runner=b};SAO.Body.foreign={};SAO.Body.get=function()return b end
SAO.Identity={get=function()return rec end}
SAO.Perception.beliefs={runner={people={},known={}}}
SAO.Perception.knownPlaces=function()return {} end
SAO.Perception.believedThreatCount=function()return 0 end
SAO.Places={at=function()return {id=7}end}
SAO.Standing.groupOf=function()return nil end
SAO.Standing.insideClaim=function()return claim end
SAO.Standing.mayEnterBelieved=function()return permission end
SAO.Disposition.traits=function()return {discipline=.5,initiative=.5,selfPreservation=.5}end
SAO.Disposition.drinkAt=function()return .5 end
SAO.Disposition.eatAt=function()return .5 end
SAO.History.countyHours=function()return hours end
SAO.Gesture={seat=function(id,body)seatArgs=id=="runner" and body==b end,standUp=function()end}
SAO.Controller.agents={runner=a}
SAO.Needs.cold=function()return 0 end
SAO.Needs.bleeding=function()return 0 end
SAO.Locomotion={cancel=function()end}
SAO.Census={classOf=function()return "other"end,skillOf=function()return 0 end}
local function fresh(f,e,h,t)
 SAO.Needs.stopRecovery("runner",b,"fixture-reset")
 __resetNative(f,e,h,t);a={rec=rec,state="IDLE"};SAO.Controller.agents.runner=a
 hours=12;permission=true;claim=true
 return SAO.Needs.read(b)
end
local n=fresh(.95,.7,.2,.1)
local admitted=SAO.Controller.__recoveryNeedsProbe("runner",a,b,100,n)
if not admitted then
 local _,why=SAO.Needs.beginRecovery("runner",b,"sleep")
 error("RECOVERY:daytime_recovery_admitted:"..tostring(why)..":"..tostring(b:getCurrentStateName())
  ..":"..tostring(b:isExistInTheWorld())..":"..tostring(SAO.Needs.workAvailable(b)))
end
check("native_sleep_owner_started",b:isAsleep() and a.sleeping
 and SAO.Needs.recoveryActive("runner",b) and rec.recoveryIntent.status=="recovering")
check("seat_receives_actual_identity_and_body",seatArgs)
check("pose_only_keeps_outcome_pending",SAO.Controller.updateRecovery("runner",a,b,100,n,nil)
 and SAO.Needs.recoveryActive("runner",b) and SAO.Needs.read(b).fatigue==n.fatigue)
__nativeTicks(2000);hours=12.1
local after=SAO.Needs.read(b)
check("native_fatigue_and_endurance_recover",after.fatigue<n.fatigue and after.endurance>n.endurance)
check("native_hunger_and_thirst_continue",after.hunger>n.hunger and after.thirst>n.thirst)
check("running_requires_measured_progress",SAO.Controller.updateRecovery("runner",a,b,101,after,nil))
permission=false
check("permission_change_interrupts",not SAO.Controller.updateRecovery("runner",a,b,102,after,nil)
 and not b:isAsleep() and SAO.Needs.recoveryRuntimeCount()==0 and rec.recoveryIntent==nil
 and SAO.Needs.read(b).fatigue==after.fatigue and after.fatigue>0.3)
permission=true;a.nextRecoveryHours=nil
check("recovery_can_resume",SAO.Controller.offerRecovery("runner",a,b,103,SAO.Needs.read(b)))
check("threat_interrupts_same_receiver",not SAO.Controller.updateRecovery("runner",a,b,104,SAO.Needs.read(b),{})
 and not b:isAsleep() and not a.recovery)
n=fresh(.95,.7,.2,.1)
check("new_attempt_admitted",SAO.Controller.offerRecovery("runner",a,b,200,n))
hours=14.4
check("native_fall_asleep_delay_is_not_false_failure",SAO.Controller.updateRecovery("runner",a,b,200,n,nil))
hours=14.51
check("pose_without_native_progress_fails_finitely",not SAO.Controller.updateRecovery("runner",a,b,201,n,nil)
 and a.pressure.detail=="recovery ended without its target" and not b:isAsleep()
 and SAO.Needs.recoveryRuntimeCount()==0 and SAO.Needs.read(b).fatigue==n.fatigue)
n=fresh(.9,.85,1,.1)
check("starving_energetic_actor_does_not_get_forced_rest",not SAO.Controller.offerRecovery("runner",a,b,300,n))
check("fatigue_is_not_work_incapacity",SAO.Needs.workAvailable(b))
check("minor_needs_do_not_preempt_social_plan",not SAO.Controller.contactNeedPriority("runner",b,{hunger=.51,thirst=.51,fatigue=1}))
check("urgent_deprivation_still_preempts",SAO.Controller.contactNeedPriority("runner",b,n))
n=fresh(.95,.7,.2,.1)
check("active_hunger_recovery_admitted",SAO.Controller.offerRecovery("runner",a,b,310,n))
__pressureNative(1,.1);n=SAO.Needs.read(b)
check("urgent_stimulus_preserves_sleep_owner",b:isAsleep() and a.recovery and n.hunger>=1)
check("active_hunger_interrupts_recovery",not SAO.Controller.updateRecovery("runner",a,b,311,n,nil)
 and not b:isAsleep() and not a.recovery and SAO.Needs.recoveryRuntimeCount()==0
 and rec.recoveryIntent==nil and SAO.Needs.read(b).fatigue==n.fatigue)
n=fresh(.95,.7,.2,.1)
check("active_thirst_recovery_admitted",SAO.Controller.offerRecovery("runner",a,b,312,n))
__pressureNative(.2,1);n=SAO.Needs.read(b)
check("active_thirst_interrupts_recovery",not SAO.Controller.updateRecovery("runner",a,b,313,n,nil)
 and not b:isAsleep() and not a.recovery and SAO.Needs.recoveryRuntimeCount()==0
 and rec.recoveryIntent==nil and SAO.Needs.read(b).fatigue==n.fatigue)
n=fresh(.95,.7,.2,.1)
check("minor_pressure_recovery_admitted",SAO.Controller.offerRecovery("runner",a,b,314,n))
__pressureNative(.51,.51);n=SAO.Needs.read(b)
check("minor_pressure_keeps_recovery",SAO.Controller.updateRecovery("runner",a,b,315,n,nil)
 and b:isAsleep() and a.recovery and SAO.Needs.recoveryActive("runner",b)
 and SAO.Needs.read(b).fatigue==n.fatigue)
-- The existing carried-relief owner is independently verified. Here its
-- controlled admission proves ordering in the actual Controller decision.
n=fresh(.95,.7,.2,.51)
local drinkCarried,readyCalls=SAO.Needs.drinkCarried,0
SAO.Needs.drinkCarried=function(id,body)
 if id=="runner" and body==b then readyCalls=readyCalls+1;return true end
 return false
end
check("ready_carried_relief_precedes_recovery",SAO.Controller.__recoveryNeedsProbe("runner",a,b,316,n)
 and readyCalls==1 and a.state=="DRINK" and not a.recovery and not b:isAsleep())
SAO.Needs.drinkCarried=drinkCarried
n=fresh(.9,.85,1,.1)
-- Only detached appraisal and external dispatch are controlled here. The
-- production admission must reach planning despite fatigue; native resource
-- completion remains the independently tested SourceUse/production owner.
local planned=0
SAO.ProceduralPlanning={planResource=function()planned=planned+1;return nil end,
 resourceDemand=function()return nil end,reconcileCooking=function()end}
SAO.Labor={};SAO.SourceUse={};SAO.WorldSources={inspectionCandidate=function()return nil end}
SAO.Census={skillOf=function()return 0 end}
SAO.Controller.advanceResourcePurpose("runner",a,b,301,n)
check("tired_survival_strategy_reaches_existing_planner",planned==1)
rec.resourceProductionWork={kind="refill-water",admittedNeeds={hunger=1,thirst=.1}}
check("fatigue_does_not_interrupt_native_resource_owner",not __productionOwner.needInterruption("runner",b,n,.7))
rec.resourceProductionWork=nil
n=fresh(.95,.7,.2,.1);claim=false
check("unknown_unadmitted_ground_is_not_rest_place",not SAO.Controller.offerRecovery("runner",a,b,400,n))
claim=true;SAO.Perception.believedThreatCount=actualThreatCount
SAO.Perception.beliefs.runner.zombies={near={x=b:getX()+1,y=b:getY(),z=0,dist=500,at=400,source="observed"}}
check("actual_private_threat_reader_declines_recovery",not SAO.Controller.offerRecovery("runner",a,b,400,n))
SAO.Perception.beliefs.runner.zombies={};SAO.Perception.believedThreatCount=function()return 0 end
claim=true;permission=false
check("denied_rest_place_refuses",not SAO.Controller.offerRecovery("runner",a,b,401,n))
permission=true;SAO.Body.active.runner=nil
check("body_binding_must_match",not SAO.Needs.beginRecovery("runner",b,"sleep"))
SAO.Body.active.runner=b;n=fresh(.2,.1,.2,.1)
check("native_endurance_rest_admitted",SAO.Controller.offerRecovery("runner",a,b,500,n) and b:isResting() and not b:isAsleep())
__nativeTicks(4000);hours=12.1
check("native_endurance_rest_completes",not SAO.Controller.updateRecovery("runner",a,b,501,SAO.Needs.read(b),nil)
 and a.pressure.detail=="recovery measured; resumes decisions" and not b:isResting()
 and SAO.Needs.recoveryRuntimeCount()==0 and rec.recoveryIntent==nil
 and SAO.Needs.read(b).endurance>=0.8 and SAO.Needs.read(b).endurance>n.endurance)
n=fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,600,n)
__nativeTicks(15000);hours=12.4
check("native_sleep_completion_is_measured",not SAO.Controller.updateRecovery("runner",a,b,601,SAO.Needs.read(b),nil)
 and a.pressure.detail=="recovery measured; resumes decisions" and not b:isAsleep()
 and SAO.Needs.recoveryRuntimeCount()==0 and rec.recoveryIntent==nil
 and SAO.Needs.read(b).fatigue<=0.3 and SAO.Needs.read(b).fatigue<n.fatigue)
-- Existing lifecycle owners retire their disposable native receiver handles.
n=fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,700,n)
check("recovery_has_one_receiver",SAO.Needs.recoveryRuntimeCount()==1)
SAO.Controller.drop("runner")
check("controller_drop_retires_without_waking_handoff",SAO.Needs.recoveryRuntimeCount()==0
 and b:isAsleep() and rec.recoveryIntent.status=="paused")
a={rec=rec,state="IDLE"};SAO.Controller.agents.runner=a
check("reloaded_native_sleep_rebinds_from_current_stats",SAO.Needs.resumeRecovery("runner",b))
SAO.Needs.retireRecovery("runner","controller-drop")
check("repeat_retirement_is_exactly_once",not SAO.Needs.retireRecovery("runner","controller-drop")
 and SAO.Needs.recoveryRuntimeCount()==0)
SAO.Controller.forget("runner")
check("forget_clears_paused_intent_without_receiver",rec.recoveryIntent==nil and b:isAsleep())
fresh(.2,.05,.2,.1);SAO.Controller.offerRecovery("runner",a,b,700,SAO.Needs.read(b))
SAO.Needs.retireRecovery("runner","controller-drop");b:setIsResting(false)
check("native_seated_rest_resumes_without_pose_credit",SAO.Needs.resumeRecovery("runner",b)
 and SAO.Needs.pollRecovery("runner",b)=="running" and SAO.Needs.recoveryActive("runner",b)
 and SAO.Needs.read(b).endurance<0.8)
fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,701,SAO.Needs.read(b))
__reloadNeeds(__needsPath)
check("module_reload_releases_prior_receiver",SAO.Needs.recoveryRuntimeCount()==0 and b:isAsleep()
 and rec.recoveryIntent.status=="paused")
check("module_reload_resumes_without_pose_credit",SAO.Controller.updateRecovery("runner",a,b,702,SAO.Needs.read(b),nil)
 and SAO.Needs.recoveryRuntimeCount()==1 and rec.recoveryIntent.status=="recovering"
 and SAO.Needs.read(b).fatigue>0.3)
local registered=false
for _,callback in ipairs(__startCallbacks)do if callback==SAO.Needs.recoveryResetHandler then registered=true end end
check("world_reset_uses_registered_owner",registered)
SAO.Needs.recoveryResetHandler()
check("world_reset_retires_without_old_world_actuation",SAO.Needs.recoveryRuntimeCount()==0 and b:isAsleep())
fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,703,SAO.Needs.read(b))
local foreign=__host;foreign:setAsleep(true);foreign:setSitOnGround(true)
SAO.Body.active.runner=foreign;SAO.Body.foreign.runner=foreign
SAO.Controller.updateRecovery("runner",a,foreign,704,SAO.Needs.read(foreign),nil)
check("replacement_foreign_body_is_never_mutated",foreign:isAsleep() and foreign:isSitOnGround()
 and b:isAsleep() and SAO.Needs.recoveryRuntimeCount()==0)
SAO.Body.active.runner=b;SAO.Body.foreign.runner=nil;foreign:setAsleep(false);foreign:setSitOnGround(false)
fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,705,SAO.Needs.read(b))
SAO.Controller.forget("runner")
check("forget_retires_native_receiver",SAO.Needs.recoveryRuntimeCount()==0)
fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,706,SAO.Needs.read(b))
b:setHealth(0);rec.dead=true
check("actual_native_body_is_dead",b:isDead())
local beforeDeathRetirement=SAO.Needs.read(b)
SAO.Controller.__recoveryDeathProbe("runner",b,rec)
check("death_retires_receiver_without_recovery_credit",SAO.Needs.recoveryRuntimeCount()==0
 and rec.recoveryIntent==nil and SAO.Needs.read(b).fatigue==beforeDeathRetirement.fatigue
 and SAO.Needs.read(b).endurance==beforeDeathRetirement.endurance)
__result="PASS loaded recovery production/native receivers "..tostring(checks).." checks"
'''


def run():
    game, jdk = fixture.GAME, fixture.JDK
    required = (game / "projectzomboid.jar", game / "stdlib.lua",
                jdk / "java.exe", jdk / "javac.exe")
    if not all(path.is_file() for path in required):
        print("Border 225 SKIPPED: installed engine VM or JDK absent; native recovery unverified")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    jar, sao = game / "projectzomboid.jar", ROOT / "mod/42.20/media/java/SAO.jar"
    cp = os.pathsep.join(map(str, [jar, game / "ZombieBuddy.jar", sao]))
    shutil.copy2(game / "stdlib.lua", OUT / "stdlib.lua")
    (OUT / "LoadedRecoveryProbe.java").write_text(JAVA, encoding="utf-8")
    (OUT / "prelude.lua").write_text(fixture.PRELUDE + "\nrequire=function()end\nISInventoryPage={}\n"
        "__startCallbacks={}\nEvents.OnGameStart.Add=function(fn)table.insert(__startCallbacks,fn)end\n"
        "Events.OnGameStart.Remove=function(fn)for i=# __startCallbacks,1,-1 do if __startCallbacks[i]==fn then table.remove(__startCallbacks,i)end end end\n", encoding="utf-8")
    (OUT / "probe.lua").write_text("local ok,why=pcall(function()\n" + LUA
        + '\nend)\nif not ok then __result="FAIL "..tostring(why) end\n', encoding="utf-8")
    controller = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"
    needs = ROOT / "mod/42.20/media/lua/client/SAO_Needs.lua"
    native = ROOT / "java/src/com/sao/engine/SAONeeds.java"
    production = ROOT / "mod/42.20/media/lua/client/SAO_ResourceProduction.lua"
    perception = ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua"
    source = controller.read_text(encoding="utf-8")
    controls = [
        ("production", None, None, None),
        ("restore-fatigue-cutoff", "and not SAO.Needs.busy(body) and needs\n",
         "and not SAO.Needs.busy(body) and needs and needs.fatigue < 0.7\n", "tired_survival_strategy_reaches_existing_planner"),
        ("restore-minor-need-monopoly", "math.max(SAO.Disposition.drinkAt(id), policy().desperation)",
         "SAO.Disposition.drinkAt(id)", "minor_needs_do_not_preempt_social_plan"),
        ("remove-day-recovery", "if Ctl.offerRecovery(id, agent, body, tick, needs) then return true end",
         "-- recovery producer omitted", "daytime_recovery_admitted"),
        ("pose-as-completion", None, None, "pose_only_keeps_outcome_pending"),
        ("restore-production-fatigue-cutoff", None, None, "fatigue_does_not_interrupt_native_resource_owner"),
        ("restore-manual-recovery", None, None, "controller_elapsed_time_grants_no_credit"),
        ("wrong-threat-arguments", "SAO.Perception.believedThreatCount(id, tick, 10, body:getX(), body:getY())",
         "SAO.Perception.believedThreatCount(id, body:getX(), body:getY(), tick)", "actual_private_threat_reader_declines_recovery"),
        ("wrong-seat-arguments", "body:setSitOnGround(true); SAO.Gesture.seat(id, body) end)", "body:setSitOnGround(true); SAO.Gesture.seat(body) end)", "seat_receives_actual_identity_and_body"),
        ("ignore-active-urgent-pressure",
         "        or needs and math.max(needs.hunger, needs.thirst) >= policy().desperation\n            and needs.endurance > 0.2 then",
         "        then", "active_hunger_interrupts_recovery"),
        ("rest-before-carried-relief",
         "local function decideNeedsAndCompanion(id, agent, body, tick, needs)\n",
         "local function decideNeedsAndCompanion(id, agent, body, tick, needs)\n    if Ctl.offerRecovery(id, agent, body, tick, needs) then return true end\n",
         "ready_carried_relief_precedes_recovery"),
        ("omit-drop-retirement", 'if SAO.Needs.retireRecovery then SAO.Needs.retireRecovery(id, "controller-drop") end',
         "-- retirement omitted", "controller_drop_retires_without_waking_handoff"),
        ("omit-death-retirement", 'if SAO.Needs.retireRecovery then SAO.Needs.retireRecovery(id, "death") end',
         "-- retirement omitted", "death_retires_receiver_without_recovery_credit"),
        ("omit-reset-retirement", None, None, "world_reset_retires_without_old_world_actuation"),
        ("omit-reload-retirement", None, None, "module_reload_releases_prior_receiver"),
        ("mutate-released-receiver", None, None, "replacement_foreign_body_is_never_mutated"),
    ]
    built = subprocess.run([str(jdk / "javac.exe"), "-encoding", "UTF-8", "-cp", cp, "-d", str(OUT),
        str(native), str(ROOT / "tools/luacheck/MovementCrossingProbe.java"), str(OUT / "LoadedRecoveryProbe.java")],
        capture_output=True, text=True, timeout=120)
    (OUT / "compile.log").write_text(built.stdout + built.stderr, encoding="utf-8")
    assert built.returncode == 0, built.stdout + built.stderr
    receipt = {"schema": "sao-loaded-recovery-checks/1", "inputs": {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in [jar, sao, controller, needs, native, production, perception, Path(__file__),
            ROOT / "tools/resource_production_test.py", ROOT / "tools/luacheck/MovementCrossingProbe.java",
            game / "media/lua/shared/defines.lua"]}, "variants": []}
    for label, before, replacement, marker in controls:
        value = source
        if before:
            assert value.count(before) == 1, (label, value.count(before))
            value = value.replace(before, replacement, 1)
        value=value.replace("return Ctl\n","Ctl.__recoveryNeedsProbe=decideNeedsAndCompanion\nCtl.__recoveryDeathProbe=retireDeadBodyWork\nreturn Ctl\n",1)
        path = OUT / (label + ".lua");path.write_text(value, encoding="utf-8")
        needs_path, production_path, variant_cp = needs, production, str(OUT) + os.pathsep + cp
        if label=="pose-as-completion":
            text=needs.read_text(encoding="utf-8");assert text.count("if reached and measured then")==1
            needs_path=OUT / "pose-needs.lua"
            needs_path.write_text(text.replace("if reached and measured then","if not measured then",1),encoding="utf-8")
        if label=="omit-reset-retirement":
            text=needs.read_text(encoding="utf-8");seam='N.recoveryResetHandler = function() N.resetRecoveries("world-reset") end'
            assert text.count(seam)==1;needs_path=OUT / "no-reset-needs.lua"
            needs_path.write_text(text.replace(seam,'N.recoveryResetHandler = function() end',1),encoding="utf-8")
        if label=="omit-reload-retirement":
            text=needs.read_text(encoding="utf-8");seam='if N.resetRecoveries then pcall(N.resetRecoveries, "module-reload") end'
            assert text.count(seam)==1;needs_path=OUT / "no-reload-needs.lua"
            needs_path.write_text(text.replace(seam,'-- prior receiver retirement omitted',1),encoding="utf-8")
        if label=="mutate-released-receiver":
            text=needs.read_text(encoding="utf-8");seam='if not retireOnly and recoveryOwner(id, body) == work.rec then'
            assert text.count(seam)==1;needs_path=OUT / "foreign-actuation-needs.lua"
            needs_path.write_text(text.replace(seam,'if not retireOnly then',1),encoding="utf-8")
        if label=="restore-production-fatigue-cutoff":
            text=production.read_text(encoding="utf-8")
            seam="if SAO.Needs.bleeding(body) > 0 then return true end";assert text.count(seam)==1
            production_path=OUT / "fatigue-production.lua"
            production_path.write_text(text.replace(seam,"if SAO.Needs.bleeding(body) > 0 or needs.fatigue >= 0.7 then return true end",1),encoding="utf-8")
        if label=="restore-manual-recovery":
            mutant=OUT / "manual-credit";mutant.mkdir(exist_ok=True)
            text=native.read_text(encoding="utf-8");seam="return shell.getStats().get(CharacterStat.FATIGUE);"
            assert text.count(seam)==1
            native_path=mutant / "SAONeeds.java"
            native_path.write_text(text.replace(seam,
                "shell.getStats().set(CharacterStat.FATIGUE, Math.max(0, shell.getStats().get(CharacterStat.FATIGUE) - (float)(hoursDelta / 8)));\n            "+seam,1),encoding="utf-8")
            compiled=subprocess.run([str(jdk / "javac.exe"),"-encoding","UTF-8","-cp",cp,"-d",str(mutant),str(native_path)],capture_output=True,text=True,timeout=120)
            assert compiled.returncode==0,compiled.stderr
            variant_cp=str(mutant)+os.pathsep+variant_cp
        (OUT / "capture-production.lua").write_text("__productionOwner=SAO.ResourceProduction\n",encoding="utf-8")
        (OUT / "needs-path.lua").write_text("__needsPath="+json.dumps(str(needs_path).replace("\\","/"))+"\n",encoding="utf-8")
        result = subprocess.run([str(jdk / "java.exe"), "-Duser.home=" + str(OUT), "-Djava.awt.headless=true",
            "--enable-native-access=ALL-UNNAMED", "-cp", variant_cp,
            "LoadedRecoveryProbe", str(game), str(OUT / "prelude.lua"),
            str(game / "media/lua/shared/ISBaseObject.lua"),
            str(game / "media/lua/shared/TimedActions/ISBaseTimedAction.lua"),
            str(game / "media/lua/shared/TimedActions/ISTransferAction.lua"),
            str(game / "media/lua/client/TimedActions/ISInventoryTransferAction.lua"),
            str(game / "media/lua/shared/TimedActions/ISTakeWaterAction.lua"),
            str(needs_path),str(OUT / "needs-path.lua"),str(perception),str(production_path), str(OUT / "capture-production.lua"),str(path), str(OUT / "probe.lua")],
            cwd=OUT, capture_output=True, text=True, timeout=120)
        output = result.stdout + result.stderr
        (OUT / (label + ".log")).write_text(output, encoding="utf-8")
        if marker:
            expected="NATIVE "+marker+"=false" if label=="restore-manual-recovery" else "RECOVERY:"+marker
            assert result.returncode != 0 and expected in output, (label, output)
        else:
            assert result.returncode == 0 and "VALUE PASS loaded recovery" in output, output
        receipt["variants"].append({"name": label, "exit": result.returncode, "expected": marker,
            "sha256": hashlib.sha256(output.encode()).hexdigest()})
        print(label + ": " + next((line for line in output.splitlines() if line.startswith("VALUE ")), output[-300:]), flush=True)
    (OUT / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("Border 225 PASS: native recovery ownership, measurement and interruption controls")


if __name__ == "__main__":
    run()
