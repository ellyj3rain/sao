"""Production recovery priority and installed native physiology; no rendered world.

Controlled private memory/permission and scheduling surround actual owned native
body receivers. The installed calculateStats method supplies every stat change.
Mutation controls restore the original work cutoff and false recovery credit.
Action callbacks and native animator observations are controlled inputs in this
headless fixture. SAO action bodies and native physiology are real; installed
external nodes are tested separately through the actual animator/native events.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

OWNER=Path(__file__).resolve().parents[1]
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'NEO.md').is_file())
sys.path.insert(0,str(ROOT/'tools'))

import flee_continuity_test as fixture

OUT = Path(os.environ.get("SAO_RECOVERY_OUTPUT", ROOT / "_scratch/shared-reasoning/recovery"))
SOURCE_MANIFEST = json.loads((ROOT/'tools/recovery_source_manifest.json').read_bytes())
EXTERNAL = Path(os.environ.get('SAO_RECOVERY_SOURCE_ROOT', SOURCE_MANIFEST['externalSourceRoot']))
TCHERNOLIB_INFO = Path(os.environ.get('SAO_RECOVERY_TCHERNOLIB_INFO', SOURCE_MANIFEST['transitiveDependency']['installedB42Path']))

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
        env.rawset("__setIdleState",(JavaFunction)(frame,count)->{
            try { state.set(body.getStateMachine(),zombie.ai.states.IdleState.instance()); }
            catch(Exception failure){throw new IllegalStateException(failure);}
            body.setSitOnGround(false);frame.push(true);return 1;
        });
        env.rawset("__setGroundState",(JavaFunction)(frame,count)->{
            try { state.set(body.getStateMachine(),zombie.ai.states.PlayerSitOnGroundState.instance()); }
            catch(Exception failure){throw new IllegalStateException(failure);}
            body.setSitOnGround(true);body.setVariable("SitGroundStarted",true);frame.push(true);return 1;
        });
        env.rawset("__pressureNative",(JavaFunction)(frame,count)->{
            stats.set(CharacterStat.HUNGER,((Number)frame.get(0)).floatValue());
            stats.set(CharacterStat.THIRST,((Number)frame.get(1)).floatValue());
            frame.push(true);return 1;
        });
        env.rawset("__resetNative",(JavaFunction)(frame,count)->{
            SAONeeds.setShellAsleep(body,false);body.setIsResting(false);body.setSitOnGround(false);
            try { state.set(body.getStateMachine(),zombie.ai.states.IdleState.instance()); }
            catch(Exception failure){throw new IllegalStateException(failure);}
            body.clearVariable("SleepStateOnGround");body.clearVariable("SitGroundStarted");
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
        if(env.rawget("RESULT")!=null)System.out.println("SNAPSHOT "+env.rawget("RESULT"));
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
local poseSeen=true
local function recoveryPlace()
 return {key="controlled-clear-ground",kind="ground",available=true,x=b:getX(),y=b:getY(),z=b:getZ()}
end
local nativeBridge=setmetatable({isRecoveryPose=function(_,body,kind) return poseSeen end,
 recoveryPlaces=function()return {actorId="runner",status="available",places={recoveryPlace()}} end,
 recoveryGroundClear=function()return __groundClear~=false end}, {
 __index=function(_,key) return function(_,...) return __bridge[key](__bridge,...) end end})
SAOJavaBridge=nativeBridge
-- Scheduling and animator delivery are explicit controlled inputs, not renderer proof.
local queued
ISTimedActionQueue={queues={}}
local q={}
function q:onCompleted(action) if queued==action then queued=nil end end
function q:resetQueue() queued=nil end
function q:removeFromQueue(action) if queued==action then queued=self.nextForeign;self.nextForeign=nil end end
ISTimedActionQueue.getTimedActionQueue=function() return q end
ISTimedActionQueue.add=function(action) queued=action;ISTimedActionQueue.queues[b]=q end
ISTimedActionQueue.hasAction=function(action) return action~=nil and queued==action end
ISLogSystem={logAction=function()end}
isClient=function()return false end;isServer=function()return false end
__sourceEnabled=true
getActivatedMods=function()return {contains=function(_,id)return __sourceEnabled and (id=='LeanAndLie' or id=='TchernoLib')end}end
TchAL.setupLieDownOnGround=function()error('forbidden installed player-key helper')end
TchAL.setVariable=function()error('forbidden installed player-key helper')end
TchAL.sleep=function()error('forbidden player sleep UI')end
TchAL.unequipHandItems=function()error('forbidden forced unequip')end
local function runAction(event)
 local action=queued
 assert(action and action.character==b,"exact source action body")
 action.action={forceComplete=function()end,forceStop=function()action:stop()end,isStarted=function()return true end}
 action:start()
 if action.update then action:update() end
 if event then action:animEvent(event,"") end
 action:perform()
 return action
end
local function advancePose(kind)
 runAction();__setGroundState()
 assert(SAO.Needs.pollRecovery("runner",b)=="preparing")
 runAction();poseSeen=true
 local result=SAO.Needs.pollRecovery("runner",b)
 if kind~="rest" then
  assert(result=="preparing");runAction("AsleepEvent")
  result=SAO.Needs.pollRecovery("runner",b)
 end
 assert(result=="running","source action admits observed physical recovery")
 SAO.Controller.updateRecovery("runner",a,b,99,SAO.Needs.read(b),nil)
end
local realOffer=SAO.Controller.offerRecovery
local autoPose=true
SAO.Controller.offerRecovery=function(id,agent,body,tick,needs)
 local admitted=realOffer(id,agent,body,tick,needs)
 if admitted and autoPose then advancePose(rec.recoveryIntent.kind) end
 return admitted
end
SAO.Body.active={runner=b};SAO.Body.foreign={};SAO.Body.get=function()return b end
SAO.Identity={get=function()return rec end}
SAO.Perception.beliefs={runner={people={},known={}}}
SAO.Perception.knownPlaces=function()return {} end
SAO.Perception.believedThreatCount=function()return 0 end
SAO.Places={at=function()return {id=7}end}
SAO.Standing.groupOf=function()return nil end
SAO.Standing.insideClaim=function()return claim end
SAO.Standing.mayEnterBelieved=function()return permission end
SAO.Standing.mayAttemptBelieved=function()return permission end
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
 hours=12;permission=true;claim=true;poseSeen=true;queued=nil;q.nextForeign=nil;q.current=nil
 return SAO.Needs.read(b)
end
local n=fresh(.95,.7,.2,.1)
local admitted=SAO.Controller.__recoveryNeedsProbe("runner",a,b,100,n)
if not admitted then
 local _,why=SAO.Needs.beginRecovery("runner",b,"sleep",recoveryPlace())
 error("RECOVERY:daytime_recovery_admitted:"..tostring(why)..":"..tostring(b:getCurrentStateName())
  ..":"..tostring(b:isExistInTheWorld())..":"..tostring(SAO.Needs.workAvailable(b)))
end
check("native_sleep_owner_started",b:isAsleep() and a.sleeping
 and SAO.Needs.recoveryActive("runner",b) and rec.recoveryIntent.status=="recovering")
check("seat_receives_actual_identity_and_body",SAO.Needs.recoveryStatus("runner",b).nativePose)
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
permission=true;a.nextRecoveryHours=nil;__setIdleState()
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
-- Match the controlled admitted drink with its carried-item observation. All
-- other bridge methods still dispatch to the exact native receiver.
SAOJavaBridge=setmetatable({findCarriedDrink=function() return {} end,
 isRecoveryPose=function(_,body,kind)return poseSeen end}, {
 __index=nativeBridge})
SAO.Needs.drinkCarried=function(id,body)
 if id=="runner" and body==b then readyCalls=readyCalls+1;return true end
 return false
end
check("ready_carried_relief_precedes_recovery",SAO.Controller.__recoveryNeedsProbe("runner",a,b,316,n)
 and readyCalls==1 and a.state=="DRINK" and not a.recovery and not b:isAsleep())
SAO.Needs.drinkCarried=drinkCarried
SAOJavaBridge=nativeBridge
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
SAO.Needs.retireRecovery("runner","controller-drop")
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

-- Explicit negative action admission controls; no mocked result is treated as rendered proof.
autoPose=false
n=fresh(.95,.7,.2,.1)
check("queued_sleep_is_not_native_sleep",realOffer("runner",a,b,750,n) and not b:isAsleep()
 and rec.recoveryIntent.status=="preparing" and not a.sleeping)
local priorSequence=rec.recoveryExperienceSequence
check("preparing_has_no_measured_segment",SAO.Needs.pollRecovery("runner",b)=="preparing"
 and rec.recoveryExperienceSequence==priorSequence)
runAction();__setGroundState();SAO.Needs.pollRecovery("runner",b)
runAction();SAO.Needs.pollRecovery("runner",b)
runAction() -- perform without AsleepEvent is deliberately insufficient
check("source_perform_without_sleep_event_is_not_sleep",SAO.Needs.pollRecovery("runner",b)=="preparing"
 and not b:isAsleep() and rec.recoveryExperienceSequence==priorSequence)
hours=12.3
check("unacknowledged_pose_times_out_without_credit",SAO.Needs.pollRecovery("runner",b)=="failed"
 and rec.recoveryExperienceSequence==priorSequence)
n=fresh(.95,.7,.2,.1);realOffer("runner",a,b,751,n)
runAction();__setGroundState();SAO.Needs.pollRecovery("runner",b)
runAction();SAO.Needs.pollRecovery("runner",b);runAction("AsleepEvent");poseSeen=false
check("sleep_event_without_native_pose_is_not_sleep",SAO.Needs.pollRecovery("runner",b)=="preparing" and not b:isAsleep())
SAO.Needs.stopRecovery("runner",b,"fixture-reset")
n=fresh(.95,.7,.2,.1);realOffer("runner",a,b,752,n)
local late=queued;SAO.Needs.stopRecovery("runner",b,"threat")
late:perform()
check("cancelled_queue_cannot_start_sleep_later",not b:isAsleep() and b:getVariableString("SleepStateOnGround")==""
 and SAO.Needs.recoveryRuntimeCount()==0)
n=fresh(.95,.7,.2,.1);realOffer("runner",a,b,753,n)
__reloadNeeds(__needsPath)
check("preparing_reload_retires_queue_without_credit",SAO.Needs.recoveryRuntimeCount()==0
 and rec.recoveryIntent and rec.recoveryIntent.status=="preparing" and not b:isAsleep())
-- Ownership changes before the next controller poll; all outstanding source
-- callbacks must be inert and preserve an unrelated queued action.
n=fresh(.95,.7,.2,.1);realOffer("runner",a,b,753,n)
runAction();__setGroundState();SAO.Needs.pollRecovery("runner",b)
local transferred=queued
local sibling={character=b};q.current=transferred;q.nextForeign=sibling
local oldX,oldY=b:getX(),b:getY()
SAO.RecoveryPose.storeAppliedOffset(b,.2,.2)
SAO.Body.active.runner=__host;SAO.Body.foreign.runner=__host
transferred:update()
check("late_update_cannot_move_transferred_body",b:getX()==oldX and b:getY()==oldY)
transferred:start();transferred:perform();transferred:stop();transferred:forceCancel()
transferred:interruptWaitToStart();transferred:animEvent("AsleepEvent","")
check("retired_callbacks_preserve_foreign_queue",queued==sibling and not transferred:isValid()
 and transferred:complete()==false and b:getVariableString("SleepStateOnGround")=="")
SAO.Needs.pollRecovery("runner",b)
check("terminal_transfer_releases_offset_without_body_actuation",SAO.RecoveryPose.appliedOffset[b]==nil
 and b:getX()==oldX and b:getY()==oldY)
SAO.Body.active.runner=b;SAO.Body.foreign.runner=nil

autoPose=true
n=fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,754,n)
check("returned_token_fixture_has_native_sleep",b:isAsleep())
local capturedX,capturedY=b:getX(),b:getY()
local oldOwnerToken=rec.bodyOwnerToken
rec.bodyOwnerToken="returned-token";b:getModData().SAOExternalToken="returned-token"
SAO.Needs.stopRecovery("runner",b,"returned-owner")
check("returned_token_old_work_cannot_wake_or_move",b:isAsleep() and b:getX()==capturedX and b:getY()==capturedY)
rec.bodyOwnerToken=oldOwnerToken;b:getModData().SAOExternalToken=oldOwnerToken
SAOJavaBridge:setShellAsleep(b,false);SAO.RecoveryPose.settle(b)
n=fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,754,n)
local blockedX,blockedY=b:getX(),b:getY();local priorExperienceCount=#(rec.recoveryExperiences or {})
__groundClear=false;SAO.Needs.stopRecovery("runner",b,"blocked-native-exit")
check("blocked_exit_releases_owned_pose_without_translation",not b:isAsleep() and b:getVariableString("SleepStateOnGround")=="" and b:getX()==blockedX and b:getY()==blockedY)
local exactExit=SAO.RecoveryPose.appliedOffset[b]
check("blocked_exit_retains_exact_receipt_without_credit",exactExit and SAO.RecoveryPose.pendingExits[b]==exactExit and rec.recoveryPoseExit.status=="pending-safe-exit" and #(rec.recoveryExperiences or {})==priorExperienceCount)
SAO.RecoveryPose.pollPendingExits()
check("blocked_exit_retry_does_not_force_clearance",b:getX()==blockedX and b:getY()==blockedY and SAO.RecoveryPose.appliedOffset[b]==exactExit)
__groundClear=true;SAO.RecoveryPose.pollPendingExits()
check("safe_exit_reverses_once",SAO.RecoveryPose.appliedOffset[b]==nil and SAO.RecoveryPose.pendingExits[b]==nil and math.abs(b:getX()-(blockedX-exactExit.x))<.0001 and math.abs(b:getY()-(blockedY-exactExit.y))<.0001)
n=fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,754,n)
__groundClear=false;SAO.Needs.stopRecovery("runner",b,"native-exit-progress")
local observedX,observedY=b:getX()+1,b:getY()+1;b:setX(observedX);b:setY(observedY)
SAO.RecoveryPose.pollPendingExits()
check("native_exit_does_not_subtract_old_offset",b:getX()==observedX and b:getY()==observedY and SAO.RecoveryPose.appliedOffset[b]==nil and rec.recoveryPoseExit.status=="observed-native-exit")
__groundClear=true
n=fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,754,n)
local oldReceipts=#(rec.recoveryExperiences or {})
__nativeTicks(15000);hours=12.4;poseSeen=false
check("lost_pose_cannot_credit_measured_physiology",SAO.Needs.pollRecovery("runner",b)=="failed"
 and #(rec.recoveryExperiences or {})==oldReceipts)

-- Reload may precede native animation reappearance. It retains ownership
-- without granting an observed segment until pose acknowledgment returns.
n=fresh(.95,.7,.2,.1);SAO.Controller.offerRecovery("runner",a,b,755,n)
SAO.Needs.retireRecovery("runner","controller-drop");poseSeen=false
local reloadSequence=rec.recoveryExperienceSequence
check("reload_waits_for_native_pose_without_orphaning_sleep",SAO.Needs.resumeRecovery("runner",b)
 and SAO.Needs.pollRecovery("runner",b)=="preparing" and b:isAsleep()
 and rec.recoveryIntent.status=="reacknowledging" and rec.recoveryExperienceSequence==reloadSequence)
SAO.Needs.retireRecovery("runner","controller-drop")
check("pending_reack_handoff_preserves_owned_intent",rec.recoveryIntent and rec.recoveryIntent.status=="paused"
 and b:isAsleep() and SAO.Needs.resumeRecovery("runner",b)
 and SAO.Needs.pollRecovery("runner",b)=="preparing" and rec.recoveryExperienceSequence==reloadSequence)
poseSeen=true
check("reload_pose_return_starts_fresh_measured_segment",SAO.Needs.pollRecovery("runner",b)=="running"
 and rec.recoveryExperienceSequence>reloadSequence)
SAO.Needs.retireRecovery("runner","controller-drop");poseSeen=false
check("reload_second_pending_ack_is_owned",SAO.Needs.resumeRecovery("runner",b))
hours=12.3
check("reload_pose_timeout_releases_native_flags",SAO.Needs.pollRecovery("runner",b)=="failed"
 and not b:isAsleep() and rec.recoveryIntent==nil and SAO.Needs.recoveryRuntimeCount()==0)

-- C120 measured recovery feeds the same person's next actual admission.
local stores={}
ModData={get=function(key)return stores[key]end,getOrCreate=function(key)stores[key]=stores[key] or {};return stores[key]end}
SAO.Identity.all=function()return {runner=rec}end
SAO.Cognition.configure(0,12,3)
rec.cognition=nil;rec.recoveryExperiences=nil
-- Delivered assent is read through the production Organization owner. It
-- remains an unfinished responsibility and supplies no material completion.
local Org=SAO.Organization
local function responsibility(actor,deliver)
 local process=Org.raiseMatter("origin","shared-recovery",nil,
  {scope={action="deliver-material",category="food",quantity=1}}, {actor}, {source="private-plan"})
 assert(process,"production responsibility proposal")
 assert(Org.recordReception(process.id,actor,process.revision,"spoken","origin",{}))
 assert(Org.appraiseMatter(process.id,actor,{owner="recovery-proof",executor="recovery-proof",
  currentActivity="idle",canAcquire=true,canCarry=true,canDeliver=true,canExecute=true,
  relationship=1,destinationKnown=true,choice="accept"}))
 if deliver then assert(Org.deliverResponse(process.id,actor,"origin","spoken",{})) end
 return process,Org.activeCommitment(actor,"shared-recovery")
end
local function clearResponsibilities() Org.processes={};Org.processOrder={} end
n=fresh(.9,.9,.2,.1)
check("shared_recovery_cold_choice_admits_sleep",SAO.Controller.offerRecovery("runner",a,b,790,n)
 and rec.recoveryIntent.kind=="sleep" and a.recoveryReasoning.selected=="sleep" and rec.cognition==nil)
local predictions={}
for _,row in ipairs(a.recoveryReasoning.models[1].ranked)do
 for _,p in ipairs(row.predictions)do predictions[p.kind]=p end
end
check("shared_recovery_exposes_sleep_and_rest_predictions",predictions.sleep and predictions.rest
 and predictions.sleep.category=="body" and predictions.rest.category=="body")
n=fresh(.1,.1,.2,.1)
check("changed_native_body_selects_rest_through_same_interpreter",SAO.Controller.offerRecovery("runner",a,b,791,n)
 and rec.recoveryIntent.kind=="rest" and b:isResting() and not b:isAsleep()
 and a.recoveryReasoning.selected=="rest")
clearResponsibilities();n=fresh(.9,.9,.2,.1)
local process,commitment=responsibility("runner",true)
check("own_delivered_assent_changes_actual_recovery_admission",commitment and commitment.acceptedAt==hours
 and not SAO.Controller.offerRecovery("runner",a,b,792,n)
 and a.recoveryReasoning.selected=="continue" and #a.recoveryReasoning.purposes==1
 and commitment.status~="completed" and not rec.recoveryIntent)
clearResponsibilities();n=fresh(.9,.9,.2,.1);responsibility("other",true)
check("foreign_responsibility_cannot_block_native_recovery",SAO.Controller.offerRecovery("runner",a,b,793,n)
 and #a.recoveryReasoning.purposes==0)
clearResponsibilities();n=fresh(.9,.9,.2,.1);process,commitment=responsibility("runner",true)
commitment.acceptedAt=hours+1
check("future_assent_cannot_block_native_recovery",SAO.Controller.offerRecovery("runner",a,b,794,n)
 and #a.recoveryReasoning.purposes==0)
clearResponsibilities();n=fresh(.9,.9,.2,.1);responsibility("runner",false)
check("undelivered_assent_cannot_block_native_recovery",SAO.Controller.offerRecovery("runner",a,b,795,n)
 and #a.recoveryReasoning.purposes==0)
clearResponsibilities()
n=fresh(.84,.9,.2,.1)
check("unexposed_close_recovery_choice_remains_active",not SAO.Controller.offerRecovery("runner",a,b,800,n))
n=fresh(.95,.7,.2,.1)
check("learning_recovery_has_native_owner",SAO.Controller.offerRecovery("runner",a,b,801,n))
local sequence=rec.recoveryExperienceSequence
__nativeTicks(15000);hours=12.4
SAO.Controller.updateRecovery("runner",a,b,802,SAO.Needs.read(b),nil)
local learned=rec.cognition
n=fresh(.84,.9,.2,.1);hours=12.5
check("recovery_learning_changes_actual_admission",SAO.Controller.offerRecovery("runner",a,b,803,n))
check("recovery_native_producer_revises_both_models",learned and learned.models.ordinary.revision==1
 and learned.models.associative.revision==1)
local receipt=SAO.Needs.behaviorOutcome("runner",sequence)
check("recovery_retains_measured_segment",receipt and receipt.beforeValue>receipt.afterValue
 and receipt.durationHours>0 and receipt.durationHours<.41 and receipt.succeeded)
check("recovery_duplicate_is_not_relearned",SAO.Cognition.behaviorOutcome("runner",receipt)
 and learned.models.ordinary.revision==1)
receipt.afterValue=receipt.beforeValue
check("recovery_fabricated_receipt_rejected",not SAO.Cognition.behaviorOutcome("runner",receipt))
receipt=SAO.Needs.behaviorOutcome("runner",sequence)
check("recovery_foreign_receipt_rejected",not SAO.Cognition.behaviorOutcome("other",receipt))

SAO.Needs.retireRecovery("runner","controller-drop")
local previousSegment=rec.recoveryExperienceSequence
hours=14
check("recovery_reload_starts_fresh_observed_segment",SAO.Needs.resumeRecovery("runner",b)
 and rec.recoveryExperienceSequence>previousSegment and SAO.Needs.pollRecovery("runner",b)=="running"
 and learned.models.ordinary.revision==1)
SAO.Needs.stopRecovery("runner",b,"interrupted")
check("interrupted_recovery_supplies_no_evidence",learned.models.ordinary.revision==1)
local function dataCopy(v) if type(v)~="table"then return v end local out={} for k,x in pairs(v)do out[k]=dataCopy(x)end return out end
rec.cognition=dataCopy(learned);SAO.Cognition.rebindWorld()
n=fresh(.84,.9,.2,.1);hours=14.1
check("recovery_saved_learning_changes_admission",SAO.Controller.offerRecovery("runner",a,b,804,n))
n=fresh(.84,.9,.2,.1);hours=240
check("recovery_old_confidence_ages_without_learning",not SAO.Controller.offerRecovery("runner",a,b,805,n)
 and rec.cognition.models.ordinary.revision==1)
n=fresh(.84,.9,.2,.1);hours=241;permission=false
check("recovery_learning_cannot_override_permission",not SAO.Controller.offerRecovery("runner",a,b,806,n))

n=fresh(.95,.7,.2,.1);hours=241
check("recovery_counterexample_has_owned_action",SAO.Controller.offerRecovery("runner",a,b,807,n))
hours=243.6
check("measured_active_no_progress_revises_expectation",SAO.Needs.pollRecovery("runner",b)=="failed"
 and rec.cognition.models.ordinary.revision==2
 and SAO.Cognition.behaviorExpectation("runner","sleep",nil,nil,hours)<.5)
local priorRevision=rec.cognition.models.ordinary.revision
n=fresh(.95,.7,.2,.1);hours=244
SAO.Controller.offerRecovery("runner",a,b,808,n)
SAO.Body.active.runner=__host;SAO.Body.foreign.runner=__host
check("replaced_recovery_receiver_creates_no_learning",SAO.Needs.pollRecovery("runner",b)=="failed"
 and rec.cognition.models.ordinary.revision==priorRevision)
SAO.Body.active.runner=b;SAO.Body.foreign.runner=nil


-- Repeated measured no-progress can change preference, while its bounded
-- contribution leaves extreme bodily pressure capable of winning the decision.
for index=1,8 do
 n=fresh(.95,.7,.2,.1);hours=250+index*3
 assert(SAO.Needs.beginRecovery("runner",b,"sleep",recoveryPlace()));advancePose("sleep")
 hours=hours+2.6
 check("recovery_repeated_observed_counterexample_"..index,SAO.Needs.pollRecovery("runner",b)=="failed")
end
n=fresh(1,.9,.2,.1);hours=277
local oldTraits=SAO.Disposition.traits
SAO.Disposition.traits=function()return {discipline=1,initiative=.5,selfPreservation=.5}end
check("learned_no_progress_cannot_veto_extreme_recovery",SAO.Controller.offerRecovery("runner",a,b,809,n))
SAO.Disposition.traits=oldTraits

MAXIMAL_EXPORT=true;MAXIMAL_SNAPSHOT=SAO.Cognition.snapshot("runner",true)
-- Other existing lifecycle cases retain their unconfigured cognition baseline.
stores={};rec.cognition=nil

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


def native_pose_checks(game, jdk, cp):
    """Installed pose observation, real queue admission and native clip events."""
    source=ROOT / "java/src/com/sao/engine/SAORecoveryPose.java"
    orientation=ROOT / "java/src/com/sao/engine/SAOOrientationAnimation.java"
    probe=ROOT / "tools/orienting_checks/RecoveryPoseProbe.java"
    parent=ROOT / "tools/orienting_checks/OrientationProbe.java"
    crossing=ROOT / "tools/luacheck/MovementCrossingProbe.java"
    pose=ROOT / "mod/42.20/media/lua/client/SAO_RecoveryPose.lua"
    action=ROOT / "mod/42.20/media/lua/shared/TimedActions/SAORecoveryTransitionAction.lua"
    inputs=[source,ROOT / "java/src/com/sao/bridge/SAOBridge.java",orientation,probe,parent,crossing,
        game / "projectzomboid.jar",game / "ZombieBuddy.jar",ROOT / "mod/42.20/media/java/SAO.jar",pose,action,
        Path(__file__),ROOT / "tools/recovery_source_manifest.json",
        game / "media/lua/shared/ISBaseObject.lua",game / "media/lua/shared/TimedActions/ISBaseTimedAction.lua",
        game / "media/AnimSets/player/sitonground-sitting/sit_action.xml"]
    inputs+=list((EXTERNAL/'media/AnimSets/player/sitonground-sitting').glob("*.xml"))
    inputs+=[EXTERNAL/'media/lua/client/TchAL_states.lua',EXTERNAL/'mod.info',TCHERNOLIB_INFO]
    inputs+=[game / ("media/anims_X/Bob/"+name+".x") for name in
        ("Bob_Awake","Bob_Asleep","Bob_AwakeToAsleep","Bob_Idle","Bob_Walk",
         "Bob_LookLeft","Bob_LookRight","Bob_LookDown","Bob_LookUp",
         "Bob_SitGround_ActionIdle","Bob_SitGround_toActionIdle")]
    pins={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    # Each changed input set gets a new folder. C120 and prior D1 raw evidence
    # remain available even when the caller uses the default OUT directory.
    out=OUT / "native-helper" / hashlib.sha256(json.dumps(pins,sort_keys=True).encode()).hexdigest()[:12]
    out.mkdir(parents=True,exist_ok=True)
    receipt_path=out / "receipt.json"
    controls=[("omit-node-identity","!nodeName.equals(source.name)","false","same_clip_wrong_node"),
        ("omit-parent-identity",'!"sitonground-sitting".equals(source.parentState.name)',"false","wrong_parent"),
        ("omit-active-node","!node.isActive()","false","fading_node_not_active"),
        ("omit-track-weight","!Float.isFinite(trackWeight) || trackWeight <= 0","false","track_weight_0.0"),
        ("omit-node-weight","Float.isFinite(nodeWeight) && nodeWeight > 0","true","zero_node_weight")]
    lua_controls=[("omit-native-handoff",pose,'        body:clearVariable(P.stateVariableOnGround)\n',
        '',"owned_transition_starts_through_native_wait"),
        ("restore-timed-sleep-transition",action,'kind == "sleep" and -1 or 2','kind == "sleep" and 50 or 2',
        "native_clip_delivers_sleep_event_before_completion"),
        ("omit-handoff-ownership",pose,'    if not owns(work) then return "failed" end\n','',
        "stale_owner_cannot_release_pose_false")]
    native_selection=os.environ.get('SAO_RECOVERY_NATIVE_CONTROLS')
    if native_selection:
        labels=set(native_selection.split(','))
        controls=[c for c in controls if c[0]in labels];lua_controls=[c for c in lua_controls if c[0]in labels]
        assert len(controls)+len(lua_controls)==len(labels),'unknown native recovery control'
    expected_checks=35
    if receipt_path.is_file():
        saved=json.loads(receipt_path.read_text(encoding="utf-8"))
        baseline=saved.get("baseline",{}); retained=saved.get("controls",[])
        log=Path(baseline.get("log","missing"))
        valid=(saved.get("status")=="PASS" and saved.get("inputs")==pins
            and baseline.get("exit")==0 and baseline.get("checks")==expected_checks and log.is_file()
            and hashlib.sha256(log.read_bytes()).hexdigest()==baseline.get("sha256")
            and len(retained)==len(controls)+len(lua_controls))
        for item,expected in zip(retained,controls+lua_controls):
            log=out / (expected[0]+".log")
            valid=valid and item.get("name")==expected[0] and item.get("caught") is True and log.is_file()
            if valid:
                text=log.read_text(encoding="utf-8")
                valid=hashlib.sha256(text.encode()).hexdigest()==item.get("logSha256")
        if valid:
            print(f"Native recovery pose REUSED: exact inputs/logs, {expected_checks} checks + {len(retained)} controls",flush=True)
            return
    classes=out / "classes";classes.mkdir(exist_ok=True)
    compile_command=[str(jdk / "javac.exe"),"-encoding","UTF-8","-cp",cp,"-d",str(classes),
        *map(str,[source,orientation,probe,parent,crossing])]
    built=subprocess.run(compile_command,capture_output=True,text=True,timeout=120)
    (out / "compile.log").write_bytes((built.stdout+built.stderr).encode("utf-8"))
    assert built.returncode==0,built.stdout+built.stderr
    native_cp=str(classes)+os.pathsep+cp
    def execute(label, first=None, pose_path=pose, action_path=action):
        command=[str(jdk / "java.exe"),"-Dsao.test.recoveryExternalRoot="+str(EXTERNAL),"-Duser.home="+str(out / ("home-"+label)),
            "-Djava.library.path="+str(game),"--enable-native-access=ALL-UNNAMED","-cp",
            (str(first)+os.pathsep if first else "")+native_cp,"RecoveryPoseProbe",str(ROOT),str(game),str(pose_path),str(action_path)]
        result=subprocess.run(command,cwd=game,capture_output=True,text=True,timeout=120)
        log=out / (label+".log");log.write_bytes((result.stdout+result.stderr).encode("utf-8"))
        return result,log,command
    result,log,command=execute("baseline")
    match=re.search(r"PASS recovery pose (\d+)",result.stdout)
    assert result.returncode==0 and match and int(match[1])==expected_checks,result.stdout+result.stderr
    receipt={"status":"RUNNING","inputs":pins,"boundary":"Installed animator/native clips; controlled body, no rendered game loop.",
        "compile":{"command":compile_command,"exit":built.returncode},"cwd":str(game),
        "baseline":{"command":command,"exit":result.returncode,"checks":expected_checks,"log":str(log),"sha256":hashlib.sha256(log.read_bytes()).hexdigest()},"controls":[]}
    original=source.read_text(encoding="utf-8")
    for label,old,new,expected in controls:
        folder=out / label;folder.mkdir(exist_ok=True);assert original.count(old)==1
        mutant=folder / source.name;mutant.write_text(original.replace(old,new,1),encoding="utf-8")
        built=subprocess.run([str(jdk / "javac.exe"),"-encoding","UTF-8","-cp",native_cp,"-d",str(folder),str(mutant)],capture_output=True,text=True,timeout=120)
        assert built.returncode==0,built.stderr
        result,log,command=execute(label,folder);text=result.stdout+result.stderr
        caught=result.returncode!=0 and "RECOVERY_POSE "+expected+"=false" in text
        receipt["controls"].append({"name":label,"command":command,"exit":result.returncode,"expected":expected,"caught":caught,"logSha256":hashlib.sha256(text.encode()).hexdigest()})
        receipt_path.write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
        assert caught,(label,text)
    for label,path,old,new,expected in lua_controls:
        folder=out / label;folder.mkdir(exist_ok=True)
        original=path.read_text(encoding="utf-8");assert original.count(old)==1
        mutant=folder / path.name;mutant.write_text(original.replace(old,new,1),encoding="utf-8")
        result,log,command=execute(label,pose_path=mutant if path==pose else pose,
            action_path=mutant if path==action else action)
        text=result.stdout+result.stderr
        caught=result.returncode!=0 and "RECOVERY_POSE "+expected+"=false" in text
        receipt["controls"].append({"name":label,"command":command,"exit":result.returncode,"expected":expected,
            "caught":caught,"logSha256":hashlib.sha256(text.encode()).hexdigest()})
        receipt_path.write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
        assert caught,(label,text)
    assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in pins.items())
    receipt["status"]="PASS";receipt["inputsUnchanged"]=True
    receipt_path.write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(f"Native recovery pose PASS: {expected_checks} checks + {len(receipt['controls'])} controls",flush=True)


def run():
    game, jdk = fixture.GAME, fixture.JDK
    required = (game / "projectzomboid.jar", game / "stdlib.lua",
                jdk / "java.exe", jdk / "javac.exe",EXTERNAL/'mod.info',TCHERNOLIB_INFO,
                EXTERNAL/'media/lua/client/TchAL_states.lua',
                EXTERNAL/'media/AnimSets/player/sitonground-sitting/sit_loop_Awake.xml',
                EXTERNAL/'media/AnimSets/player/sitonground-sitting/sit_loop_Sleep.xml',
                EXTERNAL/'media/AnimSets/player/sitonground-sitting/sit_loop_AwakeToAsleep.xml')
    if not all(path.is_file() for path in required):
        print("Border 225 SKIPPED: installed engine/JDK or required LeanAndLie/TchernoLib contracts absent; native recovery unverified")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    jar, sao = game / "projectzomboid.jar", ROOT / "mod/42.20/media/java/SAO.jar"
    cp = os.pathsep.join(map(str, [jar, game / "ZombieBuddy.jar", sao]))
    if not os.environ.get("SAO_RECOVERY_VARIANTS") or os.environ.get("SAO_RECOVERY_VARIANTS")=="native-pose":
        native_pose_checks(game,jdk,cp)
        if os.environ.get("SAO_RECOVERY_VARIANTS")=="native-pose": return
    shutil.copy2(game / "stdlib.lua", OUT / "stdlib.lua")
    (OUT / "LoadedRecoveryProbe.java").write_text(JAVA, encoding="utf-8")
    (OUT / "prelude.lua").write_text(fixture.PRELUDE + "\nrequire=function()end\nISInventoryPage={}\n"
        "ISRestAction={}\n__startCallbacks={}\nEvents.OnGameStart.Add=function(fn)table.insert(__startCallbacks,fn)end\n"
        "Events.OnGameStart.Remove=function(fn)for i=# __startCallbacks,1,-1 do if __startCallbacks[i]==fn then table.remove(__startCallbacks,i)end end end\n", encoding="utf-8")
    (OUT / "probe.lua").write_text("local ok,why=pcall(function()\n" + LUA
        + '\nend)\nif not ok then __result="FAIL "..tostring(why) end\n', encoding="utf-8")
    controller = OWNER / "mod/42.20/media/lua/client/SAO_Controller.lua"
    needs = OWNER / "mod/42.20/media/lua/client/SAO_Needs.lua"
    native = ROOT / "java/src/com/sao/engine/SAONeeds.java"
    pose = ROOT / "mod/42.20/media/lua/client/SAO_RecoveryPose.lua"
    actions = [ROOT / ("mod/42.20/media/lua/shared/TimedActions/"+name+".lua") for name in
        ["SAORecoveryTransitionAction"]]
    production = ROOT / "mod/42.20/media/lua/client/SAO_ResourceProduction.lua"
    perception = ROOT / "mod/42.20/media/lua/shared/SAO_Perception.lua"
    cognition = ROOT / "mod/42.20/media/lua/shared/SAO_Cognition.lua"
    models = ROOT / "mod/42.20/media/lua/shared/SAO_CognitiveModels.lua"
    organization = ROOT / "mod/42.20/media/lua/shared/SAO_Organization.lua"
    export = ROOT / "tools/cognition_checks/export.lua"
    source = controller.read_text(encoding="utf-8")
    controls = [
        ("production", None, None, None),
        ("omit-recovery-learning", None, None, "recovery_learning_changes_actual_admission"),
        ("ignore-recovery-learning", None, None, "recovery_learning_changes_actual_admission"),
        ("uncapped-recovery-learning", None, None, "learned_no_progress_cannot_veto_extreme_recovery"),
        ("omit-accepted-responsibility", None, None, "own_delivered_assent_changes_actual_recovery_admission"),
        ("allow-future-responsibility", None, None, "future_assent_cannot_block_native_recovery"),
        ("restore-fatigue-cutoff", "and not SAO.Needs.busy(body) and needs\n",
         "and not SAO.Needs.busy(body) and needs and needs.fatigue < 0.7\n", "tired_survival_strategy_reaches_existing_planner"),
        ("restore-minor-need-monopoly", "math.max(SAO.Disposition.drinkAt(id), policy().desperation)",
         "SAO.Disposition.drinkAt(id)", "minor_needs_do_not_preempt_social_plan"),
        ("remove-day-recovery", "function Ctl.offerRecovery(id, agent, body, tick, needs, selectedKind)\n",
         "function Ctl.offerRecovery(id, agent, body, tick, needs, selectedKind)\n    if true then return false end\n", "daytime_recovery_admitted"),
        ("pose-as-completion", None, None, "native_sleep_owner_started"),
        ("restore-production-fatigue-cutoff", None, None, "fatigue_does_not_interrupt_native_resource_owner"),
        ("restore-manual-recovery", None, None, "controller_elapsed_time_grants_no_credit"),
        ("wrong-threat-arguments", 'or not SAO.Needs.ownsRecoveryBody(id, body) then return false end\n'
         '    local kind, reasoning = SAO.Needs.recoveryPreference(id, needs, {\n'
         '        emergency = policy().desperation, committed = agent.coordinationCommitment ~= nil,\n'
         '        threat = SAO.Perception.believedThreatCount(id, tick, 10, body:getX(), body:getY())',
         'or not SAO.Needs.ownsRecoveryBody(id, body) then return false end\n'
         '    local kind, reasoning = SAO.Needs.recoveryPreference(id, needs, {\n'
         '        emergency = policy().desperation, committed = agent.coordinationCommitment ~= nil,\n'
         '        threat = SAO.Perception.believedThreatCount(id, body:getX(), body:getY(), tick)',
         "actual_private_threat_reader_declines_recovery"),
        ("omit-sleep-event", None, None, "source_perform_without_sleep_event_is_not_sleep"),
        ("omit-native-pose", None, None, "sleep_event_without_native_pose_is_not_sleep"),
        ("credit-lost-pose", None, None, "lost_pose_cannot_credit_measured_physiology"),
        ("unguarded-retired-update", None, None, "late_update_cannot_move_transferred_body"),
        ("retired-base-stop", None, None, "retired_callbacks_preserve_foreign_queue"),
        ("discard-reload-pose", None, None, "reload_waits_for_native_pose_without_orphaning_sleep"),
        ("retain-terminal-offset", None, None, "terminal_transfer_releases_offset_without_body_actuation"),
        ("omit-exit-custody", None, None, "returned_token_old_work_cannot_wake_or_move"),
        ("retain-blocked-node", None, None, "blocked_exit_releases_owned_pose_without_translation"),
        ("ignore-native-exit", None, None, "native_exit_does_not_subtract_old_offset"),
        ("discard-pending-handoff", None, None, "pending_reack_handoff_preserves_owned_intent"),
        ("ignore-active-urgent-pressure",
         "        or needs and math.max(needs.hunger, needs.thirst) >= policy().desperation\n            and needs.endurance > 0.2 then",
         "        then", "active_hunger_interrupts_recovery"),
        ("rest-before-carried-relief",
         "local function decideNeedsAndCompanion(id, agent, body, tick, needs, ordinaryExcluded)\n",
         "local function decideNeedsAndCompanion(id, agent, body, tick, needs, ordinaryExcluded)\n    if Ctl.offerRecovery(id, agent, body, tick, needs) then return true end\n",
         "ready_carried_relief_precedes_recovery"),
        ("omit-drop-retirement", 'if SAO.Needs.retireRecovery then SAO.Needs.retireRecovery(id, "controller-drop") end',
         "-- retirement omitted", "controller_drop_retires_without_waking_handoff"),
        ("omit-death-retirement", 'if SAO.Needs.retireRecovery then SAO.Needs.retireRecovery(id, "death") end',
         "-- retirement omitted", "death_retires_receiver_without_recovery_credit"),
        ("omit-reset-retirement", None, None, "world_reset_retires_without_old_world_actuation"),
        ("omit-reload-retirement", None, None, "module_reload_releases_prior_receiver"),
        ("mutate-released-receiver", None, None, "replacement_foreign_body_is_never_mutated"),
    ]
    selected = os.environ.get("SAO_RECOVERY_VARIANTS")
    if selected:
        labels=set(selected.split(","));controls=[item for item in controls if item[0] in labels]
        assert len(controls)==len(labels), "unknown recovery variant"
    compile_command=[str(jdk / "javac.exe"), "-encoding", "UTF-8", "-cp", cp, "-d", str(OUT),
        str(native), str(ROOT / "tools/luacheck/MovementCrossingProbe.java"), str(OUT / "LoadedRecoveryProbe.java")]
    built = subprocess.run(compile_command,
        capture_output=True, text=True, timeout=120)
    (OUT / "compile.log").write_bytes((built.stdout + built.stderr).encode("utf-8"))
    assert built.returncode == 0, built.stdout + built.stderr
    receipt = {"schema": "sao-loaded-recovery-checks/1", "status":"INCOMPLETE", "boundary":__doc__,
        "selection":selected,"compile":{"command":compile_command,"exit":built.returncode},
        "inputs": {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in [jar, sao, controller, needs, native, pose, *actions, production, perception, cognition, models, organization, export, Path(__file__),
            ROOT / "tools/recovery_source_manifest.json",
            ROOT / "tools/resource_production_test.py", ROOT / "tools/luacheck/MovementCrossingProbe.java",
            game / "media/lua/shared/defines.lua"]}, "variants": []}
    receipt_path=OUT / ("receipt-selection-"+hashlib.sha256(selected.encode()).hexdigest()[:12]+".json" if selected else "receipt.json")
    for label, before, replacement, marker in controls:
        value = source
        if before:
            assert value.count(before) == 1, (label, value.count(before))
            value = value.replace(before, replacement, 1)
        value=value.replace("return Ctl\n","Ctl.__recoveryNeedsProbe=decideNeedsAndCompanion\nCtl.__recoveryDeathProbe=retireDeadBodyWork\nreturn Ctl\n",1)
        path = OUT / (label + ".lua");path.write_text(value, encoding="utf-8")
        needs_path, production_path, variant_cp = needs, production, str(OUT) + os.pathsep + cp
        pose_path=pose
        if label in ("omit-sleep-event","omit-native-pose"):
            text=pose.read_text(encoding="utf-8")
            seam='work.sleepEvent and P.observed(body,"sleep")' if label=="omit-sleep-event" else 'and SAOJavaBridge:isRecoveryPose(body, kind) == true'
            replacement='P.observed(body,"sleep")' if label=="omit-sleep-event" else 'and true'
            assert text.count(seam)==1
            pose_path=OUT/(label+"-pose.lua");pose_path.write_text(text.replace(seam,replacement,1),encoding="utf-8")
        if label in ("unguarded-retired-update","retired-base-stop"):
            text=pose.read_text(encoding="utf-8")
            seam='function action:update()\n        if not owns(work) then return end' if label=="unguarded-retired-update" else 'function action:stop()\n        if not owns(work) then return end'
            replacement='function action:update()' if label=="unguarded-retired-update" else 'function action:stop()\n        if not owns(work) then return ISBaseTimedAction.stop(self) end'
            assert text.count(seam)==1
            if label=="unguarded-retired-update":
                # Both independent receiver guards now prevent a late offset.
                guard='return type(id) == "string" and SAO.Needs.ownsRecoveryBody(id, body)'
                assert text.count(guard)==1
                text=text.replace(guard,'return true',1)
            pose_path=OUT/(label+"-pose.lua");pose_path.write_text(text.replace(seam,replacement,1),encoding="utf-8")
        if label=="retain-terminal-offset":
            text=pose.read_text(encoding="utf-8");seam='if forgetOffset then\n        local receipt=P.appliedOffset[work.body]\n        if receipt then audit(receipt,"custody-unavailable") end\n        P.appliedOffset[work.body] = nil\n    end'
            assert text.count(seam)==1
            pose_path=OUT/(label+"-pose.lua");pose_path.write_text(text.replace(seam,'-- terminal offset key retained',1),encoding="utf-8")
        if label=="omit-exit-custody":
            text=needs.read_text(encoding="utf-8");seam='            if not exited and exitReason~="pending-safe-exit" then return end'
            assert text.count(seam)==1
            needs_path=OUT/(label+"-needs.lua");needs_path.write_bytes(text.replace(seam,'',1).encode("utf-8"))
        if label in ('retain-blocked-node','ignore-native-exit'):
            text=pose.read_text(encoding='utf-8')
            seam='    body:clearVariable(name)\n    if not cleared then' if label=='retain-blocked-node' else 'elseif not atAppliedPosition(body,receipt) then'
            replacement='    if cleared then body:clearVariable(name) end\n    if not cleared then' if label=='retain-blocked-node' else 'elseif false then'
            assert text.count(seam)==1
            pose_path=OUT/(label+'-pose.lua');pose_path.write_bytes(text.replace(seam,replacement,1).encode())
        if label=="discard-pending-handoff":
            text=needs.read_text(encoding="utf-8");seam='(work.phase == "active" or work.phase == "reacknowledging" or work.phase == "preparing")'
            assert text.count(seam)==1
            needs_path=OUT/(label+"-needs.lua");needs_path.write_text(text.replace(seam,'(work.phase == "active" or work.phase == "preparing")',1),encoding="utf-8")
        if label=="discard-reload-pose":
            text=needs.read_text(encoding="utf-8")
            seam='local work = { body=body, rec=rec, kind=intent.kind, phase="reacknowledging", requestedAt=now,'
            assert text.count(seam)==1
            text=text.replace(seam,'if not SAO.RecoveryPose.observed(body,intent.kind) then rec.recoveryIntent=nil;return false end\n    '+seam,1)
            needs_path=OUT/(label+"-needs.lua");needs_path.write_bytes(text.encode("utf-8"))
        if label=="credit-lost-pose":
            text=needs.read_text(encoding="utf-8")
            text=text.replace('if not status or status.phase ~= "active" then','if false then',1)
            text=text.replace('or not SAO.RecoveryPose.observed(work.body,work.kind)','or false',1)
            needs_path=OUT/(label+"-needs.lua");needs_path.write_bytes(text.encode("utf-8"))
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
            text=needs.read_text(encoding="utf-8");seam='if (not retireOnly or work.phase == "preparing") and recoveryOwner(id, body) == work.rec then'
            assert text.count(seam)==1;needs_path=OUT / "foreign-actuation-needs.lua"
            text=text.replace('            if not exited and exitReason~="pending-safe-exit" then return end','')
            text=text.replace('            local exited,exitReason=SAO.RecoveryPose.cancel(work.pose)',
                '            SAO.RecoveryPose.retire(work.pose,true)\n            local exited,exitReason=SAO.RecoveryPose.cancel(work.pose)')
            needs_path.write_text(text.replace(seam,'if not retireOnly then',1),encoding="utf-8")
        if label in ("omit-accepted-responsibility", "allow-future-responsibility"):
            text=needs.read_text(encoding="utf-8")
            seam='if context.committed or #responsibilities > 0 then' if label=="omit-accepted-responsibility" else 'obligation.acceptedAt <= now'
            replacement='if context.committed then' if label=="omit-accepted-responsibility" else 'true'
            assert text.count(seam)==1
            needs_path=OUT/(label+"-needs.lua");needs_path.write_text(text.replace(seam,replacement,1),encoding="utf-8")
        if label in ("omit-recovery-learning", "ignore-recovery-learning"):
            text=needs.read_text(encoding="utf-8")
            seam="        retainRecoveryExperience(id,work,needs,now)\n        N.stopRecovery" if label=="omit-recovery-learning" else 'consequences = value and { { kind = name, category = "body", value = value } } or {}'
            assert text.count(seam)==1
            needs_path=OUT / (label+"-needs.lua")
            needs_path.write_text(text.replace(seam,"        N.stopRecovery" if label=="omit-recovery-learning" else 'consequences = value and { { kind = name, category = "body", value = 0 } } or {}',1),encoding="utf-8")
        if label=="uncapped-recovery-learning":
            text=needs.read_text(encoding="utf-8")
            seam="maxAdjustment = 0.15,"
            assert text.count(seam)==1
            needs_path=OUT / (label+"-needs.lua")
            needs_path.write_text(text.replace(seam,"maxAdjustment = nil,",1),encoding="utf-8")
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
        command=[str(jdk / "java.exe"), "-Duser.home=" + str(OUT), "-Djava.awt.headless=true",
            "--enable-native-access=ALL-UNNAMED", "-cp", variant_cp,
            "LoadedRecoveryProbe", str(game), str(OUT / "prelude.lua"),
            str(game / "media/lua/shared/ISBaseObject.lua"),
            str(game / "media/lua/shared/TimedActions/ISBaseTimedAction.lua"),
            str(game / "media/lua/shared/TimedActions/ISTransferAction.lua"),
            str(game / "media/lua/client/TimedActions/ISInventoryTransferAction.lua"),
            str(game / "media/lua/shared/TimedActions/ISTakeWaterAction.lua"),
            str(game / "media/lua/shared/TimedActions/ISSitOnGround.lua"),
            str(EXTERNAL/'media/lua/client/TchAL_states.lua'),
            *map(str,actions),str(pose_path),
            str(models),str(cognition),str(needs_path),str(OUT / "needs-path.lua"),str(perception),str(organization),str(production_path), str(OUT / "capture-production.lua"),str(path), str(OUT / "probe.lua"), str(export)]
        result = subprocess.run(command,
            cwd=OUT, capture_output=True, text=True, timeout=120)
        output = result.stdout + result.stderr
        (OUT / (label + ".log")).write_bytes(output.encode("utf-8"))
        receipt["variants"].append({"name":label,"command":command,"exit":result.returncode,"expected":marker,
            "sha256":hashlib.sha256(output.encode()).hexdigest()})
        receipt_path.write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
        if marker:
            expected="NATIVE "+marker+"=false" if label=="restore-manual-recovery" else "RECOVERY:"+marker
            assert result.returncode != 0 and expected in output, (label, output)
        else:
            assert result.returncode == 0 and "VALUE PASS loaded recovery" in output, output
            exported=json.loads(next(line[9:] for line in output.splitlines() if line.startswith("SNAPSHOT ")))
            (OUT / "recovery-cognition-snapshot.json").write_text(json.dumps(exported,indent=2)+"\n",encoding="utf-8")
        print(label + ": " + next((line for line in output.splitlines() if line.startswith("VALUE ")), output[-300:]), flush=True)
    receipt['inputs_after']={str(p):hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in receipt['inputs']}
    assert receipt['inputs']==receipt['inputs_after'], 'relevant inputs changed during proof'
    receipt['status']='PASS'
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("Border 225 PASS: native recovery ownership, measurement and interruption controls")


if __name__ == "__main__":
    run()
