#!/usr/bin/env python3
"""Border221: assigned desired stock remains separate from means and native work.

Installed Kahlua runs production planning/Labor/Controller and the installed
water action with controlled native receivers. A separate installed native
fluid probe verifies amount/cleanliness semantics. Neither is loaded gameplay.
All compiler outputs, native caches and fixtures are private temporary paths.
"""
from pathlib import Path
import copy
import os
import re
import shutil
import subprocess
import tempfile

import resource_production_test as production
import resource_execution_test as execution
import world_lab as Lab
from lua_read import function_body

ROOT, GAME, JDK = production.ROOT, production.GAME, production.JDK
FILES = {key: production.FILES[key] for key in ("planner", "labor", "production", "controller")}
FILES["helper"] = ROOT / "tools/world_lab/StudyWorld.lua"
PRELUDE = production.PRELUDE
CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
local P,Ctl,R=SAO.ProceduralPlanning,SAO.Controller,SAO.ResourceProduction
local hash='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
local function request(category,target,deadline,revision)
    return {id='stock',revision=revision or 1,sourceDefinition=hash,issuer='experimental-study:'..hash,
        category=category,target=target,unit=category=='food' and 'usable-food-item' or 'native-clean-fluid-amount',
        deadlineAfterHours=deadline}
end
local function assigned(category,target,deadline)
    local body,agent=fixture()
    local purpose=P.admitResourceOutcome('a',request(category,target,deadline))
    return body,agent,purpose
end
local function plan(purpose)
    local context=Ctl.resourceContext('a',nil,F.body,{hunger=0,thirst=0,fatigue=0},purpose.resourceCategory,0)
    context.purposeId=purpose.id
    context.productionOptions=R.options('a',F.body,purpose.resourceCategory)
    return P.planResource('a',context),context
end
local body,agent,purpose=assigned('food',3,2)
check('operator_outcome_retains_typed_private_provenance',purpose.origin=='OperatorDirect'
    and purpose.resourceOutcome.authority=='OperatorDirect' and purpose.resourceOutcome.actorId=='a'
    and purpose.resourceOutcome.treatment=='assigned-outcome-discovery' and purpose.resourceOutcome.target==3
    and purpose.resourceOutcome.scope=='actor-owned-carried' and purpose.resourceOutcome.deadlineAt==12)
check('desired_outcome_admission_does_not_teach_means',#purpose.steps==0 and not F.rec.cognition
    and not F.rec.knownRecipes and F.queueCalls==0 and F.transferCalls==0)
local revision=purpose.revision local same,why=P.admitResourceOutcome('a',request('food',3,2))
check('save_replay_is_exact_once',same==purpose and why=='already-admitted' and same.revision==revision
    and #F.rec.proceduralPlanning.order==1 and same.resourceOutcome.deadlineAt==12)
local wrong=request('food',4,2)
check('same_revision_changed_target_is_refused',not P.admitResourceOutcome('a',wrong))
wrong=request('food',3,2) wrong.sourceDefinition='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
check('source_definition_cannot_rebind_same_request',not P.admitResourceOutcome('a',wrong))
wrong=request('food',3,2) wrong.steps={{verb='cook'}}
check('procedure_or_knowledge_injection_is_rejected',not P.admitResourceOutcome('a',wrong))
local book={kind='Food',getID=function() return 99 end,getFullType=function() return 'Base.Apple' end,
    isRotten=function() return false end,getPoisonPower=function() return 0 end,getHungChange=function() return -.1 end,
    isCookable=function() return false end,getFluidContainerFromSelfOrWorldItem=function() end}
local food={book}
SAOJavaBridge.privateCarriedItems=function() return {size=function() return #food end,get=function(self,i) return food[i+1] end} end
plan(purpose)
check('one_owned_item_does_not_satisfy_three_item_outcome',purpose.status~='completed'
    and purpose.outcomeProgress.held==1 and purpose.demand.pressure==0)
food={book,book,book} plan(purpose)
check('duplicate_native_identity_does_not_inflate_target',purpose.status~='completed' and purpose.outcomeProgress.held==1)
local function apple(id)
    local result={}; for k,v in pairs(book) do result[k]=v end
    result.getID=function() return id end return result
end
food={book,apple(100),apple(101)} plan(purpose)
check('actual_usable_owned_stock_completes_outcome',purpose.status=='completed'
    and purpose.outcomeProgress.held==3 and purpose.resolution=='native-owned-usable-stock'
    and F.transferCalls==0 and #purpose.steps==0)
check('goal_success_is_separate_from_completed_work',not F.rec.resourceProductionOutcomes
    and purpose.outcomeProgress.completeWorkIsSeparate==true)
local snapshot=P.snapshot('a').purposes[1]
check('goal_progress_and_treatment_are_observable',snapshot.resourceOutcome.target==3
    and snapshot.outcomeProgress.held==3 and snapshot.resolution=='native-owned-usable-stock')

body,agent,purpose=assigned('water',2.5)
F.amount=1.25 plan(purpose)
check('water_target_reads_native_amount_not_vessel_count',purpose.status~='completed'
    and purpose.outcomeProgress.held==1.25 and purpose.outcomeProgress.unit=='native-clean-fluid-amount')
F.amount=2.5 plan(purpose)
check('native_amount_meeting_water_target_completes',purpose.status=='completed' and purpose.outcomeProgress.held==2.5)
for _,kind in ipairs({'tainted','poison','nonwater'}) do
    body,agent,purpose=assigned('water',1) F.amount=2 F[kind]=true plan(purpose)
    check('unsafe_fluid_'..kind..'_does_not_complete',purpose.status~='completed' and purpose.outcomeProgress.held==0)
end
body,agent,purpose=assigned('water',.1) F.amount=0 plan(purpose)
check('empty_native_vessel_is_not_owned_water',purpose.status~='completed' and purpose.outcomeProgress.held==0)
body,agent,purpose=assigned('water',1) F.amount=2 F.nonwater=true
SAOJavaBridge.findCarriedDrink=function() return F.item end
local hydration=Ctl.resourceContext('a',nil,body,{thirst=.6,hunger=0,fatigue=0},'water',.5,true)
hydration.purposeId=purpose.id
P.planResource('a',hydration)
check('safe_hydration_cannot_satisfy_assigned_clean_water_outcome',purpose.status~='completed'
    and purpose.outcomeProgress.held==0 and hydration.carriedHydration==1 and hydration.carriedWater==0)
SAOJavaBridge.findCarriedDrink=nil

body,agent,purpose=assigned('water',3)
local started=Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=0,fatigue=0})
check('low_pressure_outcome_discovers_private_refill_route',started and F.action and purpose.admission
    and purpose.selectedStrategy and purpose.demand.pressure==0 and F.amount==0)
if not started then __outcomeResults=table.concat(checks,'\n') return end
local denied,why=P.admitResourceOutcome('a',request('water',4,nil,2))
check('supersession_waits_for_actual_native_owner',not denied and why=='native-attempt-active'
    and purpose.resourceOutcome.revision==1 and purpose.admission~=nil)
F.action:complete() F.action:perform() R.tick('a',body)
local receipt=F.rec.resourceProductionOutcomes[1]
check('native_work_receipt_does_not_complete_larger_stock_target',receipt and receipt.nativeGain==2
    and receipt.purposeDelivered and purpose.status~='completed' and purpose.awaitingStock and not purpose.admission)
local priorEvents=#purpose.events
P.consumeProductionResult('a',receipt)
check('work_receipt_replay_does_not_advance_goal_again',#purpose.events==priorEvents and #F.rec.resourceProductionOutcomes==1)
plan(purpose)
check('post_work_owned_stock_is_revalidated',purpose.status~='completed' and purpose.outcomeProgress.held==2)
F.amount=3 plan(purpose)
check('subsequent_actual_stock_can_finish_target',purpose.status=='completed' and purpose.outcomeProgress.held==3)

body,agent,purpose=assigned('food',2)
local successor=P.admitResourceOutcome('a',request('food',4,nil,2))
check('superseded_outcome_keeps_distinct_identity',successor and successor.id~=purpose.id
    and purpose.status=='abandoned' and purpose.resolution=='superseded' and purpose.supersededBy==successor.id
    and successor.resourceOutcome.target==4)
local own=same
body,agent,purpose=assigned('food',2,1)
F.at=11 P.resourceOutcomeDemand('a')
check('deadline_is_relative_to_actual_assignment_clock',purpose.status=='abandoned'
    and purpose.resolution=='deadline-expired' and purpose.resourceOutcome.admittedAt==10)
body,agent,purpose=assigned('food',2)
F.rec.dead=true P.resourceOutcomeDemand('a')
check('death_retires_bound_goal_without_success_or_reassignment',purpose.status=='abandoned'
    and purpose.resolution=='actor-dead' and not P.admitResourceOutcome('a',request('food',2)))
body,agent,purpose=assigned('food',2)
local saved=F.rec.proceduralPlanning
F.rec.proceduralPlanning=__nativeTableRoundtrip(saved)
local restored,why=P.admitResourceOutcome('a',request('food',2))
check('native_table_save_reload_replays_same_goal_identity',restored and restored.id==purpose.id
    and restored~=purpose and F.rec.proceduralPlanning~=saved and why=='already-admitted'
    and restored.resourceOutcome.actorId=='a' and #restored.events==#purpose.events)
purpose=restored
local oldBody=F.body
local newBody={}; for key,value in pairs(oldBody) do newBody[key]=value end
SAO.Body.active.a=newBody F.body=newBody
check('body_replacement_preserves_goal_identity',P.resourceOutcomeDemand('a')==purpose
    and not Ctl.advanceResourcePurpose('a',agent,oldBody,100,{hunger=0,thirst=0,fatigue=0}))
F.body=oldBody SAO.Body.active.a=oldBody
for i=1,40 do P.maintain('a',{key='ordinary:'..i,objective='ordinary task'}) end
check('generic_purpose_capacity_cannot_erase_assigned_goal',F.rec.proceduralPlanning.purposes[purpose.id]==purpose
    and #F.rec.proceduralPlanning.order==12 and P.admitResourceOutcome('a',request('food',2))==purpose)
local native=P.maintain('a',{key='native',objective='native attempt'}) native.admission={owner='Owner',correlationId='receipt'}
for i=1,40 do P.maintain('a',{key='later:'..i,objective='later task'}) end
check('generic_purpose_capacity_cannot_erase_native_owner',F.rec.proceduralPlanning.purposes[native.id]==native)
body,agent,purpose=assigned('food',2)
local first=purpose
for revision=2,40 do purpose=P.admitResourceOutcome('a',request('food',2,nil,revision)) end
check('successive_revisions_retire_terminal_history_without_capacity_deadlock',purpose
    and purpose.resourceOutcome.revision==40 and #F.rec.proceduralPlanning.order<=12
    and #F.rec.proceduralPlanning.resourceOutcomeRequests.stock.history==6
    and first.status=='abandoned' and first.resolution=='superseded')
body,agent=fixture() local initial
SAOJavaBridge.privateCarriedItems=function() return {size=function() return 1 end,get=function() return book end} end
for i=1,12 do
    local spec=request('food',1) spec.id='stock-'..i
    local goal=P.admitResourceOutcome('a',spec)
    if i==1 then initial=goal end
    plan(goal)
end
local ordinary=P.maintain('a',{key='after-outcomes',objective='ordinary activity'})
local replay=request('food',1) replay.id='stock-1'
local retired,why=P.admitResourceOutcome('a',replay)
check('terminal_outcomes_do_not_block_ordinary_purpose_formation',ordinary and #F.rec.proceduralPlanning.order==12)
check('retired_goal_replay_does_not_readmit_or_credit_new_success',not retired and why=='outcome-purpose-retired'
    and F.rec.proceduralPlanning.resourceOutcomeRequests['stock-1'].retired.status=='completed'
    and P.snapshot('a').resourceOutcomeRequests[1].request.sourceDefinition==hash)

body,agent,purpose=assigned('food',3)
Ctl.advanceResourcePurpose('a',agent,body,100,{hunger=0,thirst=.6,fatigue=0})
check('urgent_water_category_precedes_nonurgent_food_objective',F.rec.resourceProductionWork
    and F.rec.resourceProductionWork.kind=='refill-water'
    and F.rec.resourceProductionWork.purposeId~=purpose.id and not purpose.admission)
body,agent,purpose=assigned('water',3) F.private=false
check('assigned_goal_does_not_grant_private_source_facts',not Ctl.advanceResourcePurpose('a',agent,body,100,
    {hunger=0,thirst=0,fatigue=0}) and F.queueCalls==0 and purpose.status=='blocked')
body,agent,purpose=assigned('water',3) agent.state='COORDINATE'
check('accepted_execution_owner_precedes_new_objective',not Ctl.advanceResourcePurpose('a',agent,body,100,
    {hunger=0,thirst=0,fatigue=0}) and F.queueCalls==0)
local malformed=request('water',3) malformed.unit='litres'
check('invented_volume_unit_is_refused',not P.admitResourceOutcome('a',malformed))
local context=Ctl.resourceContext('a',nil,body,nil,'water',0) context.purposeId='missing'
check('missing_explicit_outcome_cannot_fall_back_to_another_goal',not P.planResource('a',context))
__outcomeResults=table.concat(checks,'\n')
'''

HELPER_CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
local body,agent=fixture()
local records={a=F.rec,b=F.requester}
local second={getX=function() return 2 end,getY=function() return 1.5 end,getZ=function() return 0 end}
local bodies={a=body,b=second}
SAO.Identity.all=function() return records end
SAO.Identity.get=function(id) return records[id] end
SAO.Body.get=function(id) return bodies[id] end
Config={definitionSha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',observation={sites={{id='home',x=1.5,y=1.5,z=0}}},
    situation={resourceObjectives={{id='food-stock',revision=1,siteId='home',actorOrdinal=1,category='food',
        target=3,unit='usable-food-item',deadlineAfterHours=2}}}}
state={}
getGameTime=function() return {getWorldAgeHours=function() return 410+F.at end} end
applyResourceObjectives()
local receipt=state.resourceObjectives['food-stock']
local goal=F.rec.proceduralPlanning.purposes[receipt.purposeId]
check('study_binds_actual_sorted_regional_person_once',receipt.actorId=='a' and receipt.purposeId==goal.id
    and receipt.admittedAtCountyHours==10 and receipt.deadlineAtCountyHours==12)
check('study_receipt_names_unequal_binding_and_goal_clock_domains',receipt.boundAtWorldAgeHours==420
    and receipt.admittedAtCountyHours==10 and receipt.deadlineAtCountyHours==12
    and receipt.boundAtHours==nil and receipt.admittedAtHours==nil and receipt.deadlineAtHours==nil)
check('study_admission_is_not_conversation_or_assent',receipt.treatment=='assigned-outcome-discovery'
    and receipt.issuer=='experimental-study:'..Config.definitionSha256 and not F.rec.commitments)
local purposeId=receipt.purposeId applyResourceObjectives()
check('study_save_reload_reuses_one_identity_and_purpose',receipt.purposeId==purposeId
    and #F.rec.proceduralPlanning.order==1)
bodies.a=nil applyResourceObjectives()
check('missing_body_does_not_select_nearby_other_actor',receipt.actorId=='a' and receipt.purposeId==purposeId)
F.rec.dead=true applyResourceObjectives()
check('study_dead_binding_is_terminal_not_reassigned',receipt.actorId=='a' and receipt.reason=='actor-dead'
    and goal.status=='abandoned' and not F.requester.proceduralPlanning)
records.a=nil applyResourceObjectives()
check('terminal_study_outcome_survives_later_identity_loss',receipt.actorId=='a'
    and receipt.status=='abandoned' and receipt.reason=='actor-dead')
receipt.status='maintained';receipt.reason=nil applyResourceObjectives()
check('missing_saved_identity_is_reported_without_rebinding',receipt.actorId=='a'
    and receipt.reason=='bound-identity-missing' and not F.requester.proceduralPlanning)
records.a=F.rec F.rec.dead=false bodies.a=body
F.rec.proceduralPlanning=nil state={} Config.situation.resourceObjectives[1].target=1
applyResourceObjectives() receipt=state.resourceObjectives['food-stock']
local item={kind='Food',getID=function() return 90 end,getFullType=function() return 'Base.Apple' end,
    isRotten=function() return false end,getPoisonPower=function() return 0 end,getHungChange=function() return -.1 end,
    isCookable=function() return false end,getFluidContainerFromSelfOrWorldItem=function() end}
SAOJavaBridge.privateCarriedItems=function() return {size=function() return 1 end,get=function() return item end} end
local context=SAO.Controller.resourceContext('a',nil,body,nil,'food',0) context.purposeId=receipt.purposeId
SAO.ProceduralPlanning.planResource('a',context)
for i=1,40 do SAO.ProceduralPlanning.maintain('a',{key='ordinary:'..i,objective='ordinary activity'}) end
local orderCount=#F.rec.proceduralPlanning.order applyResourceObjectives()
check('study_retired_terminal_receipt_preserves_verified_result',receipt.status=='completed'
    and receipt.reason=='native-owned-usable-stock' and receipt.held==1
    and receipt.sourceDefinition==Config.definitionSha256 and receipt.treatment=='assigned-outcome-discovery')
check('study_terminal_and_stock_receipts_retain_county_clock',receipt.resolvedAtCountyHours==10
    and receipt.stockObservedAtCountyHours==10 and receipt.boundAtWorldAgeHours==420
    and receipt.resolvedAtHours==nil and receipt.stockObservedAtHours==nil)
applyResourceObjectives()
check('study_retired_terminal_receipt_does_not_readmit',#F.rec.proceduralPlanning.order==orderCount
    and F.rec.proceduralPlanning.purposes[receipt.purposeId]==nil)
F.rec.proceduralPlanning=nil state={} F.at=10 Config.situation.resourceObjectives[1].target=3
applyResourceObjectives() receipt=state.resourceObjectives['food-stock']
F.at=13 applyResourceObjectives()
local resolved=receipt.resolvedAtCountyHours
check('study_expiry_records_original_outcome',receipt.status=='abandoned' and receipt.reason=='deadline-expired'
    and resolved==13)
F.rec.dead=true applyResourceObjectives()
check('later_death_preserves_prior_expiry',receipt.status=='abandoned' and receipt.reason=='deadline-expired'
    and receipt.resolvedAtCountyHours==resolved)
__outcomeResults=table.concat(checks,'\n')
'''

CONTROLS = [
    ("planner", "if purpose.resourceOutcome then supplied = outcomeStock(purpose, context, at) end",
     "if purpose.resourceOutcome then supplied = supplied end", "one_owned_item_does_not_satisfy_three_item_outcome", "main"),
    ("controller", "amount = fluid:getAmount()", "amount = 1", "water_target_reads_native_amount_not_vessel_count", "main"),
    ("planner", 'purpose.cursor > #purpose.steps and not purpose.resourceOutcome and "completed"',
     'purpose.cursor > #purpose.steps and "completed"', "native_work_receipt_does_not_complete_larger_stock_target", "main"),
    ("planner", "not prior.admission and (not prior.resourceOutcome\n                    or prior.status == \"completed\" or prior.status == \"abandoned\")", "not prior.admission",
     "generic_purpose_capacity_cannot_erase_assigned_goal", "main"),
    ("controller", "assigned and math.max(food, water) < 0.5", "assigned and true",
     "urgent_water_category_precedes_nonurgent_food_objective", "main"),
    ("helper", "if not receipt.actorId then", "if true then",
     "missing_saved_identity_is_reported_without_rebinding", "helper"),
    ("helper", "purpose = retired", "purpose = nil",
     "study_retired_terminal_receipt_preserves_verified_result", "helper"),
    ("helper", 'if receipt.actorId and receipt.status ~= "completed" and receipt.status ~= "abandoned" then',
     'if receipt.actorId then', "terminal_study_outcome_survives_later_identity_loss", "helper"),
    ("helper", "receipt.boundAtWorldAgeHours = getGameTime():getWorldAgeHours()",
     "receipt.boundAtWorldAgeHours = SAO.History.countyHours()",
     "study_receipt_names_unequal_binding_and_goal_clock_domains", "helper"),
]


def definition_checks():
    base = copy.deepcopy(Lab.load(ROOT / "tools/world_lab/definition.example.json"))
    origin = base["origins"][0]
    base["observation"]["sites"] = [{"id":"home", "label":"Home", **{k:origin[k] for k in ("x","y","z")}}]
    row = {"id":"stock", "revision":1, "siteId":"home", "actorOrdinal":1,
           "category":"water", "target":2.5, "unit":"native-clean-fluid-amount", "deadlineAfterHours":2}
    base["situation"] = {"resourceObjectives":[row]}
    Lab.validate(base)
    bad = [dict(row, unit="litres"), dict(row, target=True), dict(row, category="food"),
           dict(row, target=float("nan")), dict(row, siteId="missing"), dict(row, actorOrdinal=0),
           dict(row, deadlineAfterHours=0), dict(row, steps=["cook"]), dict(row, recipes=["known"])]
    for candidate in bad:
        value = copy.deepcopy(base); value["situation"]["resourceObjectives"]=[candidate]
        try: Lab.validate(value)
        except ValueError: continue
        raise RuntimeError("invalid outcome definition accepted: " + str(candidate))
    value=copy.deepcopy(base); value["situation"]["resourceObjectives"]=[row,row]
    try: Lab.validate(value)
    except ValueError: return 11
    raise RuntimeError("duplicate outcome request accepted")


def main():
    definition_count = definition_checks()
    if not (GAME / "projectzomboid.jar").is_file() or not (JDK / "javac.exe").is_file():
        print(f"Border221 native/Kahlua SKIPPED: game or JDK absent; {definition_count} Python definitions passed")
        return 0
    texts = {key:path.read_text(encoding="utf-8-sig") for key,path in FILES.items()}
    try:
        with tempfile.TemporaryDirectory(prefix="sao-resource-outcome-") as directory:
            work=Path(directory); shutil.copy2(GAME/"stdlib.lua",work/"stdlib.lua")
            runner=(ROOT/"tools/luacheck/LuaRun.java").read_text(encoding="utf-8-sig")
            anchor="thread.debugOwnerThread = Thread.currentThread();"
            if runner.count(anchor)!=1:raise RuntimeError("native table runner join differs")
            runner=runner.replace(anchor,anchor+'''
        zombie.Lua.LuaManager.platform = platform;
        env.rawset("__nativeTableRoundtrip", new se.krka.kahlua.vm.JavaFunction() {
            public int call(se.krka.kahlua.vm.LuaCallFrame frame, int args) {
                KahluaTable source = (KahluaTable) frame.get(0);
                java.nio.ByteBuffer bytes = java.nio.ByteBuffer.allocate(1048576);
                KahluaTable restored = platform.newTable();
                try {
                    source.save(bytes); bytes.flip();
                    restored.load(bytes, zombie.iso.IsoWorld.getWorldVersion());
                } catch (java.io.IOException error) { throw new RuntimeException(error); }
                if (bytes.hasRemaining()) throw new AssertionError("native table bytes remain");
                frame.push(restored); return 1;
            }
        });
''',1)
            private_runner=work/"LuaRun.java";private_runner.write_text(runner,encoding="utf-8")
            built=subprocess.run([str(JDK/"javac.exe"),"-cp",str(GAME/"projectzomboid.jar"),"-d",str(work),
                str(private_runner)],capture_output=True,text=True,timeout=60)
            if built.returncode: raise RuntimeError("Kahlua runner compile: "+built.stderr[-2500:])

            def run(kind,changed=None,target=None):
                code=dict(texts);code.update(changed or {})
                paths=[]
                def add(name,source):
                    path=work/(name+".lua");path.write_text(source,encoding="utf-8");paths.append(path)
                add("prelude",PRELUDE+"\nSAO.Controller={agents={}}\n")
                paths.extend([GAME/"media/lua/shared/ISBaseObject.lua",GAME/"media/lua/shared/TimedActions/ISBaseTimedAction.lua",
                    GAME/"media/lua/shared/TimedActions/ISTakeWaterAction.lua"])
                for name in ("labor","planner","production"): add(name,code[name])
                add("controller",execution.controller_phases(code["controller"]))
                cases=CASES if kind=="main" else HELPER_CASES
                if kind=="helper":
                    add("helper", "function keys(value) local out={} for key in pairs(value) do out[#out+1]=key end table.sort(out) return out end\n"
                        +"function applyResourceObjectives("+function_body(code["helper"],"applyResourceObjectives")+"end\n")
                diagnostic=cases.replace("checks[#checks+1]=name..'='..tostring(value==true)",
                    "checks[#checks+1]=name..'='..tostring(value==true) __lastOutcomeCheck=name __outcomeResults=table.concat(checks,'\\n')")
                add("cases","local ok,err=pcall(function()\n"+diagnostic
                    +"\nend) if not ok then __outcomeFault=tostring(err)..' after '..tostring(__lastOutcomeCheck) end\n")
                done=subprocess.run([str(JDK/"java.exe"),"-Duser.home="+str(work),"-Djava.awt.headless=true","-cp",str(work)+os.pathsep+str(GAME/"projectzomboid.jar"),
                    "LuaRun",*map(str,paths),"--","tostring(__outcomeResults)..'\\nFAULT '..tostring(__outcomeFault)"],cwd=work,capture_output=True,text=True,timeout=60)
                expected=set(re.findall(r"check\('([a-z0-9_]+)'",cases))
                # The three unsafe-fluid cases deliberately share one loop.
                expected.discard("unsafe_fluid_")
                if kind=="main":expected.update("unsafe_fluid_"+k+"_does_not_complete" for k in ("tainted","poison","nonwater"))
                values=dict(re.findall(r"([a-z0-9_]+)=(true|false)",done.stdout))
                if target and values.get(target)=="false":return values
                if done.returncode or set(values)!=expected:
                    raise RuntimeError(kind+": "+done.stdout[-6500:]+done.stderr[-1800:]+" expected="+str(expected-set(values)))
                return values
            total=0
            for kind in ("main","helper"):
                values=run(kind)
                failed=[key for key,val in values.items() if val!="true"]
                if failed:raise RuntimeError("failed focused cases: "+str(failed))
                total+=len(values)
            for name,before,after,target,kind in CONTROLS:
                if texts[name].count(before)!=1:raise RuntimeError(target+": mutation anchor differs")
                values=run(kind,{name:texts[name].replace(before,after,1)},target)
                if values[target]!="false":raise RuntimeError(target+": old defect survived")
            cp=os.pathsep.join(map(str,[GAME/"projectzomboid.jar",GAME/"ZombieBuddy.jar",ROOT/"mod/42.20/media/java/SAO.jar"]))
            sources=[ROOT/"tools/luacheck/MovementCrossingProbe.java",ROOT/"tools/luacheck/ResourceApproachProbe.java",
                     ROOT/"tools/resource_outcome_checks/NativeStockProbe.java",
                     ROOT/"java/src/com/sao/engine/SAONeeds.java"]
            built=subprocess.run([str(JDK/"javac.exe"),"-encoding","UTF-8","-cp",cp,"-d",str(work),*map(str,sources)],
                capture_output=True,text=True,timeout=60)
            if built.returncode:raise RuntimeError("native stock compile: "+built.stderr[-2500:])
            done=subprocess.run([str(JDK/"java.exe"),"-Duser.home="+str(work),"-Djava.awt.headless=true",
                "--enable-native-access=ALL-UNNAMED","-cp",str(work)+os.pathsep+cp,"NativeStockProbe"],
                cwd=work,capture_output=True,text=True,timeout=60)
            if done.returncode or "NATIVE_OUTCOME_STOCK_OK" not in done.stdout:
                raise RuntimeError("native stock probe: "+done.stdout[-2500:]+done.stderr[-2000:])
            native_source=(ROOT/"java/src/com/sao/engine/SAONeeds.java").read_text(encoding="utf-8")
            native_controls=[
                ("unsafe-primary", "|| fluidContainer.isPoisonous() || fluidContainer.isTainted()", "|| false",
                    "tainted_soda_primary_is_not_safe_hydration"),
                ("water-only", "|| fluid == zombie.entity.components.fluids.Fluid.SodaPop", "|| false",
                    "native_hydration_SodaPop"),
                ("poison-ignored", "|| fluidContainer.isPoisonous()", "|| false",
                    "poison_water_primary_is_not_safe_hydration"),
                ("cola-omitted", '|| fluid == zombie.entity.components.fluids.Fluid.Get("Cola")', "|| false",
                    "native_hydration_Cola"),
                ("diet-cola-omitted", '|| fluid == zombie.entity.components.fluids.Fluid.Get("ColaDiet")', "|| false",
                    "native_hydration_ColaDiet"),
            ]
            for name,before,after,marker in native_controls:
                if native_source.count(before)!=1:raise RuntimeError(name+": native mutation anchor differs")
                mutant=work/name; mutant.mkdir()
                path=mutant/"SAONeeds.java";path.write_text(native_source.replace(before,after,1),encoding="utf-8")
                built=subprocess.run([str(JDK/"javac.exe"),"-encoding","UTF-8","-cp",cp,"-d",str(mutant),str(path)],
                    capture_output=True,text=True,timeout=60)
                if built.returncode:raise RuntimeError(name+": native mutant compile: "+built.stderr[-2000:])
                negative=subprocess.run([str(JDK/"java.exe"),"-Duser.home="+str(mutant),"-Djava.awt.headless=true",
                    "--enable-native-access=ALL-UNNAMED","-cp",str(mutant)+os.pathsep+str(work)+os.pathsep+cp,"NativeStockProbe"],
                    cwd=mutant,capture_output=True,text=True,timeout=60)
                if negative.returncode==0 or "CHECK "+marker+"=false" not in negative.stdout:
                    raise RuntimeError(name+": native causal control did not fail its named assertion: "+negative.stdout[-1800:])
            native_count=len(re.findall(r'CHECK [^=]+=true',done.stdout))
            print(f"Border 221 PASS: {total} installed Kahlua cases; {len(CONTROLS)} named controls; {native_count} native stock checks; {len(native_controls)} native controls; {definition_count} Python definition checks")
            return 0
    except Exception as error:
        print("FAULT Border221:",error)
        return 1


if __name__=="__main__":raise SystemExit(main())
