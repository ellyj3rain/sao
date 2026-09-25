#!/usr/bin/env python3
"""Border 196: private situations become matters before any shared answer."""
from __future__ import annotations

import pathlib
import re
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod/42.20/media/lua"
ORG = LUA / "shared/SAO_Organization.lua"
COMM = LUA / "shared/SAO_Communication.lua"
GRAPH = LUA / "shared/SAO_GraphPersistence.lua"
PERCEPTION = LUA / "shared/SAO_Perception.lua"
COORDINATION = LUA / "shared/SAO_Coordination.lua"
DORMANT = LUA / "client/SAO_DormantPopulation.lua"
CAPTURE = ROOT / "tools/sweep/decision_capture.lua"
CONTROLLER = LUA / "client/SAO_Controller.lua"
EXCHANGE = LUA / "client/SAO_Exchange.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "java/out/luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"


PRELUDE = r'''
_G.__now = 240
_G.__records = {
  origin={id='origin',forename='Origin',surname='Border',dead=false,
    x=0,y=0,z=0,homeX=0,homeY=0,homeZ=0,lastWaterDay=6,lastFoodDay=10,
    dormantSleeping=false,speechAccessOrigin='generated-empty-traits'},
  recipient={id='recipient',forename='Recipient',surname='Border',dead=false,
    designation='forager',x=100,y=0,z=0,homeX=100,homeY=0,homeZ=0,
    lastWaterDay=10,lastFoodDay=10,dormantSleeping=false,
    speechAccessOrigin='generated-empty-traits'},
  silent={id='silent',forename='Silent',surname='Border',dead=false,
    x=100,y=1,z=0,homeX=100,homeY=1,homeZ=0,lastWaterDay=10,lastFoodDay=10,
    dormantSleeping=false,speechAccessOrigin='generated-empty-traits'},
  lost={id='lost',forename='Lost',surname='Border',dead=true,
    x=1,y=1,z=0,homeX=1,homeY=1,homeZ=0,lastWaterDay=10,lastFoodDay=10,
    dormantSleeping=false,speechAccessOrigin='generated-empty-traits'},
  external={id='external',forename='External',surname='Border',dead=false,
    bodyOwner='ZAO',x=20,y=20,z=0,homeX=20,homeY=20,homeZ=0,
    dormantSleeping=false,speechAccessOrigin='generated-empty-traits'},
}
local relation={
  origin={recipient=.8,silent=.5,lost=.2},
  recipient={origin=.8},silent={origin=.5},external={origin=.4},
}
SAO={
 Log={line=function() end,tally=function() end},
 History={countyHours=function() return __now end,ticks=function() return __now*9000 end},
 Identity={get=function(id) return __records[id] end,
  idByName=function(name)
   for id,rec in pairs(__records) do
    if rec.forename..' '..rec.surname==name then return id end
   end
  end},
 Body={active={},foreign={},get=function() return nil end,
  hasRepresentation=function() return false end},
 Controller={agents={}},
 Perception={beliefs={
  origin={zombies={},factions={},places={},people={
   ['Recipient Border']={id='recipient',x=100,y=0,at=20,atHours=220,
    source='observed'},
   ['Silent Border']={id='silent',x=100,y=1,at=19,atHours=219,
    source='observed'},
   -- The originator has not learned this death. Addressing may retain the
   -- person, but communication must still fail rather than leak world truth.
   ['Lost Border']={id='lost',x=1,y=1,at=18,atHours=218,source='observed'},
  }},
  recipient={zombies={},factions={},places={},people={
   ['Origin Border']={id='origin',at=20,atHours=220,source='observed'}}},
  silent={zombies={},factions={},places={},people={
   ['Origin Border']={id='origin',at=20,atHours=220,source='observed'}}},
  external={zombies={},factions={},places={},people={
   ['Origin Border']={id='origin',at=20,atHours=220,source='observed'}}},
 }},
 Standing={
  relationsOf=function(id)
   local out={}; for other,value in pairs(relation[id] or {}) do
    out[other]={trust=value,hostile=false}
   end; return out
  end,
  trust=function(id,other) return relation[id] and relation[id][other] or 0 end,
  isHostileTo=function() return false end,groupOf=function() return nil end,
 },
 Needs={read=function() return {hunger=0,thirst=0,fatigue=0} end},
 Disposition={drinkAt=function() return .5 end,eatAt=function() return .5 end,
  circle=function() return 'open' end,traits=function() return {} end},
 Conditions={of=function() return {} end,memoryFactor=function() return 1 end},
 Habits={of=function() return {} end},
 Lessons={has=function() return false end,renderClaims=function() return {} end},
 Census={JOB_PERK={},classOf=function() return 'unknown' end,
  skillOf=function() return 0 end},
}
SAOJavaBridge={
 canConverseNow=function() return false end,
 speechWeatherHearing=function() return 1 end,
 hibernationHearingAccess=function() return 'AVAILABLE:1' end,
}
plainNameOf=function(a,b) return a..' '..b end
getSpecificPlayer=function() return nil end
SandboxVars={SurvivorAwareness={Desperation=.7}}
Events=setmetatable({}, {__index=function(t,k)
 local slot={Add=function() end,Remove=function() end}; rawset(t,k,slot); return slot
end})
_G.__stores={SurvivorAwareness_Graph={schema=3,
 branching={patterns={},offices={}},
 organization={organizations={},offices={},claims={},decisions={},
  claimHistory={},decisionHistory={},processes={},processOrder={},
  processMeta={sequence=0},workReceipts={}},
 settlement={bases={}},material={stores={},reconciliations={},sourceOwners={}},
 communication={messages={}},player={claims={}},migrations={}}}
ModData={getOrCreate=function(key)
 __stores[key]=__stores[key] or {}; return __stores[key]
end}
'''


PROBE = r'''(function()
 local checks={}
 local function check(name,value)
  checks[#checks+1]=name..'='..tostring(value==true)
 end
 SAO.GraphPersistence.bind()

 local known=SAO.Perception.knownPeople('origin')
 local knownIds={}
 for _,row in ipairs(known) do knownIds[row.id]=true end
 check('private_knowledge_does_not_leak_unobserved_death',
  knownIds.recipient and knownIds.silent and knownIds.lost)

 local process,status=SAO.Coordination.originatePrivateSituation(
  'origin',nil,'dormant','Border196.private-need')
 local recipientRow=process and process.participants.recipient
 local silentRow=process and process.participants.silent
 local lostRow=process and process.participants.lost
 check('personal_need_raises_addressed_matter_without_group_or_larder',
  process~=nil and status=='open-unheard' and process.kind=='provisioning'
  and process.organizationId==nil and process.revision==1
  and process.revisions['1'].proposal.scope.category=='water'
  and process.privateInputs.origin['1'].needOwner
   =='SAO.DormantPopulation.personal-survival-history')
 check('address_is_not_reception_or_answer',recipientRow and silentRow and lostRow
  and recipientRow.receptions['1']==nil and silentRow.receptions['1']==nil
  and lostRow.receptions['1']==nil
  and #SAO.Organization.pendingProposals('origin','recipient')==1
  and #SAO.Organization.pendingAppraisals('recipient')==0)
 check('originator_authorship_is_not_recipient_appraisal',
  #SAO.Organization.pendingAppraisals('origin')==0)
 local firstContact=SAO.Coordination.pendingContact('origin')
 local firstGoal=SAO.DormantPopulation.pendingContactGoal(
  'origin',__records.origin,225000)
 check('unheard_matter_selects_private_contact_address',
  firstContact and firstContact.recipientId=='recipient'
  and firstContact.x==100 and firstContact.processId==process.id
  and firstGoal and firstGoal.contact==true
  and firstGoal.recipientId=='recipient' and firstGoal.x==100)

 -- Give the originator an unrelated leg already in progress. A current
 -- addressed matter must replace it at the next native movement gate rather
 -- than waiting for that trip to end. The replacement is durable set-out
 -- evidence, not reception.
 SAO.WorldSources={reconcileReservations=function() end,
  ownsActor=function() return false end,pendingActionFor=function() return nil end}
 SAO.Claims={isHeld=function() return false end}
 SAO.Rand={int=function(a,b) return a end,unit=function() return .5 end}
 SAO.Places={comfortHorizon=function() return 240 end}
 SAO.History.countyTimeOfDay=function() return 12 end
 SAO.History.speedModOf=function() return 1 end
 SAO.Identity.all=function() return {origin=__records.origin} end
 __records.origin.dayGoalX=-50; __records.origin.dayGoalY=0
 __records.origin.nextDormantMoveAt=0; __records.origin.lastWalkHours=239
 SAO.DormantPopulation.dormantLife({},225000)
 local contactAttempt=process.contactAttempts[1]
 check('dormant_contact_supersedes_ordinary_leg_without_implied_reception',
  __records.origin.dayGoalX==100
  and __records.origin.dayGoalProcessId==process.id
  and __records.origin.dayGoalRecipientId=='recipient'
  and __records.origin.x>0
  and contactAttempt and contactAttempt.status=='travelling'
  and recipientRow.receptions['1']==nil)

 local originalRelations=SAO.Standing.relationsOf
 SAO.Standing.relationsOf=function(id)
  if id=='origin' then return {
   recipient={trust=.1,hostile=false},silent={trust=.95,hostile=false},
   lost={trust=.2,hostile=false}}
  end
  return originalRelations(id)
 end
 local continuedContact=SAO.Coordination.pendingContact('origin')
 SAO.Standing.relationsOf=originalRelations
 check('active_contact_survives_recipient_reranking',continuedContact
  and continuedContact.recipientId=='recipient'
  and continuedContact.processId==process.id
  and SAO.Organization.activeContact(process.id,'origin','recipient')
   ==contactAttempt)

 -- A new private sighting of the same person updates the route evidence; it
 -- must not manufacture a second contact attempt or reset the first one's
 -- eventual unanswered deadline.
 local recipientBelief=SAO.Perception.beliefs.origin.people['Recipient Border']
 recipientBelief.at=21; recipientBelief.atHours=240.5; recipientBelief.x=101
 __now=240.5; __records.origin.nextDormantMoveAt=0
 SAO.DormantPopulation.dormantLife({},225500)
 check('fresh_sighting_retargets_same_contact_attempt',
  SAO.Organization.activeContact(process.id,'origin','recipient')
   ==contactAttempt
  and #process.contactAttempts==1
  and __records.origin.dayGoalSeenAt==21
  and __records.origin.dayGoalX==101
  and contactAttempt.status=='travelling')

 __records.recipient.x=__records.origin.x+1
 __now=241; __records.origin.nextDormantMoveAt=0
 local originateBeforeTravel=SAO.Coordination.originatePrivateSituation
 SAO.Coordination.originatePrivateSituation=function(id,...)
  if id=='origin' then return process,'already-open' end
  return originateBeforeTravel(id,...)
 end
 SAO.DormantPopulation.dormantLife({},226000)
 SAO.Coordination.originatePrivateSituation=originateBeforeTravel
 local currentKey=tostring(process.revision)
 local received=recipientRow.receptions[currentKey]
 local response=recipientRow.responses[currentKey]
 check('scheduler_records_actual_reception',received~=nil
  and received.channel=='dormant-encounter')
 check('scheduler_forms_recipient_private_response',response~=nil
  and response.response=='accept')
 check('scheduler_returns_recipient_response',response~=nil
  and response.delivered==true)
 check('scheduler_reception_ends_contact_attempt',
  contactAttempt.status=='received')
 check('actual_conversation_carries_and_returns_actor_private_response',
  received~=nil
  and received.channel=='dormant-encounter' and response~=nil
 and response.response=='accept' and response.delivered==true
  and SAO.Organization.activeCommitment('recipient','provisioning')~=nil
  and contactAttempt.status=='received')
 local secondContact=SAO.Coordination.pendingContact('origin')
 check('reception_advances_to_next_unheard_recipient',
  secondContact and secondContact.recipientId=='silent')

 __records.silent.x=__records.origin.x+1
 local silentMessage=SAO.Communication.deliverProcessProposal(
  'origin','silent',process.id,'dormant-encounter',{event='heard-without-answer'})
 check('heard_person_can_remain_unanswered',silentMessage~=nil
  and silentRow.receptions['1']~=nil and silentRow.responses['1']==nil
  and #SAO.Organization.pendingAppraisals('silent')==1)
 check('unreachable_known_person_remains_unheard',
  lostRow.receptions['1']==nil and lostRow.responses['1']==nil
  and SAO.Coordination.pendingContact('origin').recipientId=='lost')
 local staleAttempt=SAO.Organization.beginContact(process.id,'origin','lost',{
  owner='Border196.stale-address'})
 local staleEnded=staleAttempt and SAO.Organization.finishContact(process.id,
  staleAttempt.id,'origin','arrived',{event='old-address-checked'})
 check('reaching_stale_address_does_not_manufacture_reception',
  staleEnded==true and staleAttempt.status=='arrived'
  and lostRow.receptions['1']==nil and lostRow.responses['1']==nil)

 local externalCalls,nativeExternalCalls=0,0
 local nativeSituation=SAO.DormantPopulation.privateProvisioningSituation
 SAO.DormantPopulation.privateProvisioningSituation=function(id,...)
  if id=='external' then nativeExternalCalls=nativeExternalCalls+1 end
  return nativeSituation(id,...)
 end
 local externalContext=nil
 local externalContactCalls=0
 SAO.Communication.registerExecutionOwner('ZAO',{
  bodyFor=function() return nil end,
  originateMatter=function(id,rec,context)
   externalCalls=externalCalls+1; externalContext=context
   return {id='external-owner-result',originatorId=id},'owner-dispatched'
  end,
  advanceContact=function(id,rec,candidate,context)
   externalContactCalls=externalContactCalls+1
   return candidate and candidate.recipientId=='origin'
    and context.atHours==__now,'owner-contact'
  end,
 })
 local externalResult,externalStatus=SAO.Coordination.originatePrivateSituation(
  'external',nil,'dormant','Border196.external')
 check('external_body_dispatches_to_registered_execution_owner',
  externalCalls==1 and nativeExternalCalls==0
  and externalResult and externalResult.id=='external-owner-result'
  and externalStatus=='owner-dispatched' and externalContext
  and externalContext.knownContacts[1].id=='origin')
 local externalContact,externalContactStatus=SAO.Communication.actorContactStep(
  'external',{recipientId='origin',x=0,y=0},{atHours=__now})
 check('external_contact_continues_under_registered_owner',
  externalContact==true and externalContactStatus=='owner-contact'
  and externalContactCalls==1)

 local captureOwner=SAODecisionCapture.beginCoordination({
  runId='Border196',county='PrivateSituation'})
 local capture=captureOwner.finish()
 check('process_observation_separates_matter_from_decision',
  string.find(capture,'"eventCount":0',1,true)~=nil
  and string.find(capture,'"processCount":1',1,true)~=nil
  and string.find(capture,'"addressedCount":3',1,true)~=nil
  and string.find(capture,'"receptionCount":2',1,true)~=nil
  and string.find(capture,'"responseCount":1',1,true)~=nil
  and string.find(capture,'"returnedResponseCount":1',1,true)~=nil
  and string.find(capture,'"currentUnheardCount":1',1,true)~=nil
  and string.find(capture,'"currentUnansweredCount":1',1,true)~=nil
  and string.find(capture,'"contactAttemptCount":3',1,true)~=nil
  and string.find(capture,'"contactOutcomeCounts"',1,true)~=nil
  and string.find(capture,'"arrived":1',1,true)~=nil
  and string.find(capture,'"received":2',1,true)~=nil)

 __records.loadedOrigin={id='loadedOrigin',forename='Loaded',surname='Origin',
  dead=false,x=0,y=10,z=0,homeX=0,homeY=10,homeZ=0,
  dormantSleeping=false,speechAccessOrigin='generated-empty-traits'}
 __records.loadedRecipient={id='loadedRecipient',forename='Loaded',
  surname='Recipient',dead=false,x=30,y=10,z=0,homeX=30,homeY=10,homeZ=0,
  dormantSleeping=false,speechAccessOrigin='generated-empty-traits'}
 SAO.Perception.beliefs.loadedOrigin={zombies={},factions={},places={},people={
  ['Loaded Recipient']={id='loadedRecipient',x=30,y=10,dist=30,
   at=40,atHours=230,source='observed'}}}
 local loadedProcess=SAO.Organization.raiseMatter('loadedOrigin',
  'contact-probe',nil,{intentKey='loaded-contact',requiredCapabilities={
   execute=true},scope={action='speak'}},{'loadedRecipient'},{source='private'})
 local ordered=nil
 SAO.Locomotion={jobs={},order=function(id,b,x,y,z)
  ordered={id=id,x=x,y=y,z=z}; return true
 end,cancel=function() end}
 local loadedBody={x=0,y=10,z=0}
 function loadedBody:getX() return self.x end
 function loadedBody:getY() return self.y end
 function loadedBody:getZ() return self.z end
 local loadedAgent={state='IDLE',rec=__records.loadedOrigin}
 local sought=SAO.Controller.seekPendingContact('loadedOrigin',loadedAgent,
  loadedBody,230000)
 check('loaded_contact_uses_locomotion_without_reception',sought==true
  and loadedAgent.state=='CONTACTWARD' and ordered and ordered.x==30
  and loadedAgent.contactProcessId==loadedProcess.id
  and loadedAgent.contactAttemptId~=nil
  and loadedProcess.contactAttempts[1].status=='travelling'
  and loadedProcess.participants.loadedRecipient.receptions['1']==nil)
 __records.loadedRecipient.x=1
 local loadedExchange=SAO.Communication.exchangeProcesses('loadedOrigin',
  'loadedRecipient','dormant-encounter',{event='recipient-actually-met'})
 check('actual_reception_ends_matching_loaded_contact_attempt',
  loadedExchange~=nil and loadedProcess.contactAttempts[1].status=='received'
  and loadedProcess.participants.loadedRecipient.receptions['1']~=nil)

 -- A loaded arrival is durable presence, not a terminal success. The actor
 -- stays at the privately known address for one county day, remains
 -- interruptible, and spends the stale lead only when that opportunity ends
 -- without an actual conversation.
 __records.waitOrigin={id='waitOrigin',forename='Wait',surname='Origin',
  dead=false,x=40,y=10,z=0,homeX=40,homeY=10,homeZ=0,
  dormantSleeping=false,speechAccessOrigin='generated-empty-traits'}
 __records.waitTarget={id='waitTarget',forename='Wait',surname='Target',
  dead=false,x=70,y=10,z=0,homeX=70,homeY=10,homeZ=0,
  dormantSleeping=false,speechAccessOrigin='generated-empty-traits'}
 SAO.Perception.beliefs.waitOrigin={zombies={},factions={},places={},people={
  ['Wait Target']={id='waitTarget',x=40,y=10,dist=0,
   at=50,atHours=249,source='observed'}}}
 local waitProcess=SAO.Organization.raiseMatter('waitOrigin','contact-wait',nil,
  {intentKey='wait-at-address',requiredCapabilities={execute=true},
   scope={action='speak'}},{'waitTarget'},{source='private'})
 local waitBody={x=40,y=10,z=0}
 function waitBody:getX() return self.x end
 function waitBody:getY() return self.y end
 function waitBody:getZ() return self.z end
 local waitAgent={state='IDLE',rec=__records.waitOrigin}
 __now=250
 local beganWait=SAO.Controller.seekPendingContact('waitOrigin',waitAgent,
  waitBody,250000)
 local waitAttempt=waitProcess.contactAttempts[1]
 check('arrival_becomes_durable_presence_not_reception',beganWait==true
  and waitAgent.state=='CONTACTWAIT' and waitAttempt.status=='waiting'
  and waitAttempt.arrivedAt==250 and waitAttempt.waitUntilAt==274
  and SAO.Organization.activeContact(waitProcess.id,'waitOrigin','waitTarget')
   ==waitAttempt
  and waitProcess.participants.waitTarget.receptions['1']==nil)
 SAO.Controller.agents.waitOrigin=waitAgent
 local droppedWait=SAO.Controller.drop('waitOrigin')
 local resumedWait={state='IDLE',rec=__records.waitOrigin}
 local reconstructed=SAO.Controller.seekPendingContact('waitOrigin',resumedWait,
  waitBody,250100)
 check('loaded_dormant_handoff_preserves_same_contact_attempt',droppedWait==true
  and SAO.Controller.agents.waitOrigin==nil and reconstructed==true
  and resumedWait.state=='CONTACTWAIT'
  and resumedWait.contactAttemptId==waitAttempt.id
  and #waitProcess.contactAttempts==1 and waitAttempt.status=='waiting')
 SAO.Organization.processes={}; SAO.Organization.processOrder={}
 SAO.Organization.processMeta={sequence=0}; SAO.Organization.workReceipts={}
 local contactRebound=SAO.GraphPersistence.bind()
 local reboundWait=SAO.Organization.processes[waitProcess.id]
 check('save_rebind_preserves_active_contact_presence',contactRebound==true
  and reboundWait~=nil and reboundWait.contactAttempts[1]==waitAttempt
  and reboundWait.contactAttempts[1].status=='waiting'
  and reboundWait.contactAttempts[1].waitUntilAt==274)
 __now=275
 local waitedOut=SAO.Controller.waitPendingContact('waitOrigin',resumedWait,
  waitBody,275000)
 check('silent_address_wait_ends_unanswered_without_hearing',waitedOut==true
  and resumedWait.state=='IDLE' and waitAttempt.status=='unanswered'
  and waitProcess.participants.waitTarget.receptions['1']==nil
  and SAO.Perception.beliefs.waitOrigin.people['Wait Target'].lookedAt==275000)
 return table.concat(checks,',')
end)()'''


EXPECTED = {
    "private_knowledge_does_not_leak_unobserved_death",
    "personal_need_raises_addressed_matter_without_group_or_larder",
    "address_is_not_reception_or_answer",
    "originator_authorship_is_not_recipient_appraisal",
    "unheard_matter_selects_private_contact_address",
    "dormant_contact_supersedes_ordinary_leg_without_implied_reception",
    "active_contact_survives_recipient_reranking",
    "fresh_sighting_retargets_same_contact_attempt",
    "actual_conversation_carries_and_returns_actor_private_response",
    "scheduler_records_actual_reception",
    "scheduler_forms_recipient_private_response",
    "scheduler_returns_recipient_response",
    "scheduler_reception_ends_contact_attempt",
    "reception_advances_to_next_unheard_recipient",
    "heard_person_can_remain_unanswered",
    "unreachable_known_person_remains_unheard",
    "reaching_stale_address_does_not_manufacture_reception",
    "external_body_dispatches_to_registered_execution_owner",
    "external_contact_continues_under_registered_owner",
    "process_observation_separates_matter_from_decision",
    "loaded_contact_uses_locomotion_without_reception",
    "actual_reception_ends_matching_loaded_contact_attempt",
    "arrival_becomes_durable_presence_not_reception",
    "loaded_dormant_handoff_preserves_same_contact_attempt",
    "save_rebind_preserves_active_contact_presence",
    "silent_address_wait_ends_unanswered_without_hearing",
}


def compile_runner() -> tuple[bool, str]:
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, done.stderr or done.stdout


def run_probe(sources: dict[str, str]) -> tuple[str | None, str]:
    with tempfile.TemporaryDirectory(prefix="sao-private-situation-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        files = {
            "prelude.lua": PRELUDE,
            "organization.lua": sources["organization"],
            "communication.lua": sources["communication"],
            "graph.lua": sources["graph"],
            "perception.lua": sources["perception"],
            "dormant.lua": sources["dormant"],
            "coordination.lua": sources["coordination"],
            "controller.lua": sources["controller"],
            "capture.lua": sources["capture"],
            "probe.lua": "__result = " + PROBE,
        }
        paths = []
        for name, source in files.items():
            path = work / name
            path.write_text(source, encoding="utf-8")
            paths.append(str(path))
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun", *paths,
             "--", "__result"], cwd=work, capture_output=True, text=True,
            timeout=300)
    output = (done.stdout or "") + (done.stderr or "")
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, output


def verdicts(value: str | None) -> dict[str, str]:
    return dict(re.findall(r"([a-z0-9_]+)=(true|false)", value or ""))


def static_contract(sources: dict[str, str]) -> tuple[bool, str]:
    required = {
        "private retained contacts": ("perception", "function P.knownPeople(id)"),
        "native and external origin dispatch": (
            "coordination", "function Coordination.originatePrivateSituation"),
        "current unheard proposals": ("organization", "function Org.pendingProposals"),
        "real exchange": ("communication", "function Communication.exchangeProcesses"),
        "process observation": ("capture", 'schema = "sao-shared-process-observation"'),
        "loaded contact continuation": ("controller", "function Ctl.seekPendingContact"),
        "durable contact attempts": ("organization", "function Org.beginContact"),
        "durable address presence": ("organization", "function Org.arriveContact"),
    }
    for name, (source, anchor) in required.items():
        if anchor not in sources[source]:
            return False, f"missing {name}"
    if "SAO.Coordination.originatePrivateSituation" not in CONTROLLER.read_text(
            encoding="utf-8-sig"):
        return False, "loaded survivor producer is not called"
    dormant = sources["dormant"]
    if ("SAO.Coordination.originatePrivateSituation" not in dormant
            or "SAO.Communication.exchangeProcesses" not in dormant):
        return False, "dormant producer/exchange path is not called"
    if "SAO.Communication.exchangeProcesses" not in EXCHANGE.read_text(
            encoding="utf-8-sig"):
        return False, "loaded encounter exchange is not called"
    return True, "loaded and dormant people raise, hear and answer through native owners"


def main() -> int:
    print("=" * 74)
    print("PRIVATE SITUATION PRODUCERS AND ACTUAL COMMUNICATION")
    print("=" * 74)
    required = [ORG, COMM, GRAPH, PERCEPTION, COORDINATION, DORMANT, CAPTURE,
                CONTROLLER, EXCHANGE, RUNNER]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print("  FAULT: repository input absent: " + ", ".join(map(str, missing)))
        return 1
    installed = [PZ, STDLIB, JDK / "java.exe", JDK / "javac.exe"]
    if not all(path.is_file() for path in installed):
        print("Border 196 SKIPPED: installed game VM or JDK absent")
        return 0
    sources = {
        "organization": ORG.read_text(encoding="utf-8-sig"),
        "communication": COMM.read_text(encoding="utf-8-sig"),
        "graph": GRAPH.read_text(encoding="utf-8-sig"),
        "perception": PERCEPTION.read_text(encoding="utf-8-sig"),
        "dormant": DORMANT.read_text(encoding="utf-8-sig"),
        "coordination": COORDINATION.read_text(encoding="utf-8-sig"),
        "capture": CAPTURE.read_text(encoding="utf-8-sig"),
        "controller": CONTROLLER.read_text(encoding="utf-8-sig"),
    }
    static_ok, detail = static_contract(sources)
    print("  static contract: " + ("PASS" if static_ok else "FAIL")
          + " (" + detail + ")")
    built, detail = compile_runner()
    if not built:
        print("  FAULT: runner compile failed " + detail[-1000:])
        return 1
    value, output = run_probe(sources)
    found = verdicts(value)
    failed = sorted(name for name, result in found.items() if result != "true")
    controls = [
        ("personal producer required", "coordination",
         "local situation, why = SAO.DormantPopulation.privateProvisioningSituation(\n        id, body)",
         "local situation, why = nil, 'producer-disabled'"),
        ("address is not reception", "organization",
         "local reception = row and row.receptions and row.receptions[key] or nil",
         "local reception = row and row.receptions and row.receptions[key] or { at = 0 }"),
        ("originator cannot appraise authorship", "organization",
         "and process.originatorId ~= personId and row and row.addressed",
         "and row and row.addressed"),
        ("real transport required", "communication",
         "local channel, why = admittedConversation(fromId, toId, requestedChannel)",
         "local channel, why = 'spoken', nil"),
        ("external owner dispatch required", "coordination",
         "if rec.bodyOwner then\n        if not (SAO.Communication",
         "if false and rec.bodyOwner then\n        if not (SAO.Communication"),
        ("retained private contacts required", "coordination",
         "local contacts = SAO.Perception and SAO.Perception.knownPeople\n        and SAO.Perception.knownPeople(id) or {}",
         "local contacts = {}"),
        ("unanswered topology observed", "capture",
         "currentUnansweredCount = math.max(0,\n                currentReceived - currentResponded),",
         "currentUnansweredCount = 0,"),
        ("dormant contact continuation required", "dormant",
         "local candidate = SAO.Coordination and SAO.Coordination.pendingContact\n"
         "        and SAO.Coordination.pendingContact(id) or nil",
         "local candidate = nil"),
        ("loaded contact uses locomotion owner", "controller",
         'math.floor(body:getZ()), "CONTACTWARD",',
         'math.floor(body:getZ()), "ROAM",'),
        ("external contact stays with registered owner", "communication",
         'if type(owner.advanceContact) ~= "function" then',
         'if true then'),
        ("new matter supersedes an ordinary dormant leg", "dormant",
         "local contact = D.pendingContactGoal(id, rec, tickCounter)\n"
         "                        local spokenContacts = {}",
         "local contact = nil\n"
         "                        local spokenContacts = {}"),
        ("dormant scheduler tries actual conversation before travel", "dormant",
         'id, contact.recipientId, "dormant-encounter", {',
         'id, contact.recipientId, "spoken", {'),
        ("reception closes the matching contact attempt", "organization",
         'endOpenContacts(process, "received", personId, {',
         'endOpenContacts(process, "interrupted", personId, {'),
        ("contact attempts are observed", "capture",
         "contactAttemptCount = contactAttemptCount + 1",
         "contactAttemptCount = contactAttemptCount + 0"),
        ("active contact precedes fresh recipient ranking", "coordination",
         "if SAO.Organization.activeContact then\n"
         "        for _, candidate in ipairs(eligible) do",
         "if false and SAO.Organization.activeContact then\n"
         "        for _, candidate in ipairs(eligible) do"),
        ("fresh sighting preserves the same contact attempt", "dormant",
         "and rec.dayGoalRecipientId == contact.recipientId\n",
         "and rec.dayGoalRecipientId == contact.recipientId\n"
         "                            and rec.dayGoalSeenAt == contact.seenAt\n"),
        ("arrival remains distinct from reception", "organization",
         'attempt.status = "waiting"',
         'attempt.status = "arrived"'),
        ("silent address wait ends unanswered", "controller",
         'finishLoadedContact(id, agent, "unanswered", {',
         'finishLoadedContact(id, agent, "arrived", {'),
    ]
    controls_ok = True
    for name, target, old, new in controls:
        if sources[target].count(old) != 1:
            print(f"  FAULT: {name} mutation seam changed")
            controls_ok = False
            continue
        changed = dict(sources)
        changed[target] = changed[target].replace(old, new, 1)
        mutant_value, _ = run_probe(changed)
        mutant = verdicts(mutant_value)
        if set(mutant) == EXPECTED and all(
                result == "true" for result in mutant.values()):
            print(f"  FAULT: {name} mutation survived")
            controls_ok = False
    print("  mutation controls: " + ("PASS" if controls_ok else "FAIL")
          + " (eighteen production controls)")
    if not static_ok or not controls_ok or set(found) != EXPECTED or failed:
        print("  FAULT: missing=" + repr(sorted(EXPECTED - set(found)))
              + " failed=" + repr(failed) + " value=" + repr(value))
        print("  " + output[-3000:].replace("\n", " "))
        return 1
    print("  196) private need raises a durable matter; address, reception, answer, "
          "return and ownership remain separate observed events")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
