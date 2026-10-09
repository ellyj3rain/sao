#!/usr/bin/env python3
"""Exercise Week One inquiry dispatch and read-only native follow-up in Kahlua.

The source task actuator is a controlled GetMoveTask stub. This proves the SAO
person/decision/poll contract, not loaded Bandits movement or rendered play.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import tempfile

from weekone_active_program_test import PORTS
from weekone_companion_program_test import FIXTURE
from weekone_continuity_test import GAME, JDK, PRELUDE, ROOT, SOURCE


SETUP = r'''
__target='none' __threat=0 __freshReceipt=false __conceptReads=0 __finishes={}
__terminalFailures=0
local priorFeature=SAOJavaBridge.weekOneObservedFeature
SAOJavaBridge.weekOneObservedFeature=function(self,body,square,kind)
 if kind=='ground' then return __featureVisible and square==__road end
 return priorFeature(self,body,square,kind)
end
__road.getRoom=function()return nil end
SAO.Perception.conceptObservationReceipt=function(id,body,tick)
 return __freshReceipt and __freshBody==body and __freshTick==tick
  and math.floor(body:getX())==__freshTileX end
SAO.Perception.observeConcepts=function(id,body,tick)
 __conceptReads=__conceptReads+1
 __freshReceipt=true __freshBody=body __freshTick=tick
 __freshTileX=math.floor(body:getX())
 return true
end
SAO.ProceduralPlanning={
 situationInquiryOffer=function(id,body,tick)
  return {mode='situation',subject='unclassified-sound',questionKey='unclassified-sound',
   approach={x=86,y=80,z=0},utility=.9}
 end,
 planSourceSituationInquiry=function(id,body,offer,tick)
  __sequence=(__sequence or 0)+1
  return {id='purpose/inquiry',inquiry={sourceSelection={sequence=__sequence}}},
   {target='remembered:ground:86:80:0@exterior',x=86,y=80,z=0}
 end,
 finishSourceSituationInquiry=function(id,body,purposeId,sequence,result,tick)
  __finishes[#__finishes+1]={id=id,body=body,purposeId=purposeId,
   sequence=sequence,result=result,tick=tick}
  if result~='observed' and __terminalFailures>0 then
   __terminalFailures=__terminalFailures-1 return false end
  return true
 end}
SAO.Cognition.interpretPlans=function(id,candidates,context)
 local selected
 for _,candidate in ipairs(candidates) do
  if candidate.kind=='inquiry' then selected=candidate.id end
 end
 return {selected=selected,selectedModelId='ordinary',atHours=169,models={}}
end
'''

CASES = r'''
local W=SAO.WeekOneContinuity
__step='selected-route'
local brain,body=__actor(901,'BanditsWeekOne','Walker','Main')
local selected=W.ordinaryProgramStage(brain,body,'Walker','Main')
local person=body.md.SAOWeekOnePersonId
local phase=person and __records[person].weekOne
assert(selected and selected.tasks[1] and selected.tasks[1].action=='Move'
 and selected.tasks[1].x==86 and phase.sourceInquiry
 and phase.decision.purpose=='investigate-personally-heard-sound'
 and __stores.SurvivorAwareness_WeekOneContinuity.pendingSourceInquiryByPerson[person],
 'SAO private inquiry did not select BWO physical movement')
__step='not-yet-arrived'
assert(W.observePendingSourceInquiries()==0 and #__finishes==0
 and __conceptReads==0,'route completion was inferred before physical arrival')
__step='fresh-observed-position'
body.x=86.5 body.y=80.5
W.onTick()
assert(#__finishes==1 and __finishes[1].result=='observed'
 and __finishes[1].body==body and __conceptReads==1
 and phase.sourceInquiry==nil and phase.lastSourceInquiry.status=='recorded',
 'exact position and fresh sight did not reconcile private inquiry')
__step='rebind-interruption'
body.x=80 body.y=80 __freshReceipt=false __tick=121
local second=W.ordinaryProgramStage(brain,body,'Walker','Main')
assert(second and second.tasks[1] and phase.sourceInquiry,
 'second private inquiry was not selected')
W.rebindWorld()
__terminalFailures=1
W.onTick()
assert(#__finishes==2 and __finishes[2].result=='interrupted'
 and __finishes[2].body==nil and phase.sourceInquiry
 and phase.sourceInquiry.terminalResult=='interrupted'
 and __stores.SurvivorAwareness_WeekOneContinuity.pendingSourceInquiryByPerson[person],
 'terminal planning failure lost the pending source inquiry')
W.onTick()
assert(#__finishes==2,'failed terminal revision repeated within one county tick')
__step='terminal-retry-preserved'
__tick=122 W.onTick()
assert(#__finishes==3 and __finishes[3].result=='interrupted'
 and phase.sourceInquiry==nil and phase.lastSourceInquiry.status=='recorded',
 'failed terminal revision was not retried with original result')
__step='bounded-deadline'
__tick=142
local third=W.ordinaryProgramStage(brain,body,'Walker','Main')
assert(third and third.tasks[1] and phase.sourceInquiry,
 'third private inquiry was not selected')
__tick=1042
W.onTick()
assert(#__finishes==4 and __finishes[4].result=='deadline'
 and phase.sourceInquiry==nil and phase.lastSourceInquiry.status=='recorded',
 'deadline depended on source task callback or scan queue')
__step='durable-terminal-failure'
__tick=1100
local fourth=W.ordinaryProgramStage(brain,body,'Walker','Main')
assert(fourth and fourth.tasks[1] and phase.sourceInquiry,
 'fourth private inquiry was not selected')
W.rebindWorld() __terminalFailures=20
for n=1,16 do __tick=1100+n W.onTick() end
assert(phase.sourceInquiry and phase.sourceInquiry.status=='reconciliation-unavailable'
 and phase.lastSourceInquiry.status=='reconciliation-unavailable'
 and phase.sourceInquiry.nextRetryTick==1356
 and __stores.SurvivorAwareness_WeekOneContinuity.pendingSourceInquiryByPerson[person],
 'unavailable planner was silently completed or lost its retry')
__step='bounded-unresolved-backoff'
local beforeRecovery=#__finishes
__terminalFailures=0 __tick=1355 W.onTick()
assert(#__finishes==beforeRecovery,
 'unresolved terminal attempt retried before its county deadline')
__step='automatic-terminal-recovery'
__tick=1356 W.onTick()
assert(#__finishes==beforeRecovery+1 and phase.sourceInquiry==nil
 and phase.lastSourceInquiry.status=='recorded'
 and __stores.SurvivorAwareness_WeekOneContinuity.pendingSourceInquiryByPerson[person]==nil,
 'durable failure did not automatically retry the same attempt')
-- A changing native table can repeatedly yield the same unfinished prefix.
-- Its discovery result must not delay the tail of already admitted work.
local queuedPeople, blockedPeople, prefix = {}, {}, {}
for n=1,20 do
 __tick=2000+n
 local queuedBrain,queuedBody=__actor(1000+n,'BanditsWeekOne','Walker','Main')
 local admitted=W.ordinaryProgramStage(queuedBrain,queuedBody,'Walker','Main')
 local queuedPerson=queuedBody.md.SAOWeekOnePersonId
 assert(admitted and admitted.tasks[1] and __records[queuedPerson].weekOne.sourceInquiry,
  'changing-table fixture did not admit actual person work')
 queuedPeople[n]=queuedPerson
 if n<=16 then prefix[n]=queuedPerson blockedPeople[queuedPerson]=true end
end
local oldPoll=SAOJavaBridge.weekOnePollEntries
local discoveryCalls=0
SAOJavaBridge.weekOnePollEntries=function(self,source,stream,limit)
 if stream=='SourceInquiryPersons' then
  assert(limit==16,'inquiry discovery exceeded its raw-key bound')
  discoveryCalls=discoveryCalls+1 return prefix
 end
 return oldPoll(self,source,stream,limit)
end
local oldFinish=SAO.ProceduralPlanning.finishSourceSituationInquiry
SAO.ProceduralPlanning.finishSourceSituationInquiry=function(id,body,purposeId,sequence,result,tick)
 local recorded=oldFinish(id,body,purposeId,sequence,result,tick)
 return not blockedPeople[id] and recorded
end
__step='bounded-churn-first-slice' __tick=4000
local beforeChurn=#__finishes
assert(W.observePendingSourceInquiries()==0 and #__finishes-beforeChurn==16,
 'known inquiry scheduling did not visit sixteen distinct admitted attempts')
__step='bounded-churn-tail'
assert(W.observePendingSourceInquiries()==4 and #__finishes-beforeChurn==20
 and discoveryCalls==2,
 'changing discovery prefix starved already admitted tail work')
for n=17,20 do
 local queuedPhase=__records[queuedPeople[n]].weekOne
 assert(queuedPhase.sourceInquiry==nil and queuedPhase.lastSourceInquiry.result=='deadline',
  'round robin lost a retained tail inquiry or fabricated observed arrival')
end
__step='unavailable-discovery-preserves-known-work'
SAOJavaBridge.weekOnePollEntries=function(self,source,stream,limit)
 if stream=='SourceInquiryPersons' then return nil end
 return oldPoll(self,source,stream,limit)
end
blockedPeople={} __tick=4001
local beforeUnavailable=#__finishes
assert(W.observePendingSourceInquiries()==16 and #__finishes-beforeUnavailable==16,
 'unavailable discovery stopped previously admitted inquiry reconciliation')
__step='rebind-discards-runtime-queue' __tick=4100
local reloadBrain,reloadBody=__actor(1100,'BanditsWeekOne','Walker','Main')
local reloadWork=W.ordinaryProgramStage(reloadBrain,reloadBody,'Walker','Main')
local reloadPerson=reloadBody.md.SAOWeekOnePersonId
local reloadPhase=reloadPerson and __records[reloadPerson].weekOne
assert(reloadWork and reloadPhase.sourceInquiry,'rebind fixture did not admit work')
W.rebindWorld() __tick=5100
local beforeRebind=#__finishes
assert(W.observePendingSourceInquiries()==0 and #__finishes==beforeRebind
 and reloadPhase.sourceInquiry,
 'world rebind retained a previous runtime queue as current authority')
__step='durable-pending-rediscovered-after-rebind'
SAOJavaBridge.weekOnePollEntries=function(self,source,stream,limit)
 if stream=='SourceInquiryPersons' then return {reloadPerson} end
 return oldPoll(self,source,stream,limit)
end
assert(W.observePendingSourceInquiries()==1 and reloadPhase.sourceInquiry==nil
 and reloadPhase.lastSourceInquiry.result=='interrupted'
 and __finishes[#__finishes].body==nil,
 'saved pending inquiry was lost or borrowed a body after runtime rediscovery')
-- Successful native body observation repairs restored pending admission.
-- The inquiry retains its separate world/body authority and terminal backoff.
SAO.ProceduralPlanning.finishSourceSituationInquiry=oldFinish
__tick=6000
local restoredBrain,restoredBody=__actor(1200,'BanditsWeekOne','Walker','Main')
local restoredWork=W.ordinaryProgramStage(restoredBrain,restoredBody,'Walker','Main')
local restoredPerson=restoredBody.md.SAOWeekOnePersonId
local restoredPhase=restoredPerson and __records[restoredPerson].weekOne
assert(restoredWork and restoredPhase.sourceInquiry,'restored-body fixture did not admit original work')
W.rebindWorld()
SAOJavaBridge.weekOnePollEntries=function(self,source,stream,limit)
 if stream=='SourceInquiryPersons' then return nil end
 return oldPoll(self,source,stream,limit)
end
local durablePending=__stores.SurvivorAwareness_WeekOneContinuity.pendingSourceInquiryByPerson
durablePending[restoredPerson]=nil
__tick=6100
local beforeRestored=#__finishes
__step='restored-body-marker-refusal'
restoredBody.md.SAOWeekOnePersonId='another-person'
local refused,refusal=W.observeBrain(restoredBrain,restoredBody)
assert(refused==nil and refusal=='body-marker-conflict'
 and durablePending[restoredPerson]==nil
 and W.observePendingSourceInquiries()==0 and #__finishes==beforeRestored,
 'foreign body marker admitted restored pending inquiry work')
restoredBody.md.SAOWeekOnePersonId=restoredPerson
__step='restored-body-pending-admission'
assert(W.observeBrain(restoredBrain,restoredBody)==restoredPerson
 and durablePending[restoredPerson]==true,
 'exact restored body did not repair durable pending admission')
assert(W.observeBrain(restoredBrain,restoredBody)==restoredPerson,
 'repeated exact body observation changed person identity')
assert(W.observePendingSourceInquiries()==1 and restoredPhase.sourceInquiry==nil
 and restoredPhase.lastSourceInquiry.result=='interrupted'
 and #__finishes==beforeRestored+1 and __finishes[#__finishes].body==nil
 and W.observePendingSourceInquiries()==0,
 'restored scheduling lost work, duplicated it or borrowed prior-world body authority')
__step='restored-body-backoff-preserved'
__tick=7000
local backoffBrain,backoffBody=__actor(1201,'BanditsWeekOne','Walker','Main')
local backoffWork=W.ordinaryProgramStage(backoffBrain,backoffBody,'Walker','Main')
local backoffPerson=backoffBody.md.SAOWeekOnePersonId
local backoffPhase=backoffPerson and __records[backoffPerson].weekOne
assert(backoffWork and backoffPhase.sourceInquiry,'body backoff fixture did not admit work')
W.rebindWorld()
assert(W.observeBrain(backoffBrain,backoffBody)==backoffPerson)
__terminalFailures=20
for n=1,16 do __tick=7000+n W.observePendingSourceInquiries() end
assert(backoffPhase.sourceInquiry and backoffPhase.sourceInquiry.nextRetryTick==7256,
 'restored inquiry did not retain finite reconciliation backoff')
local beforeBodyBackoff=#__finishes
for n=1,4 do
 __tick=7016+n
 assert(W.observeBrain(backoffBrain,backoffBody)==backoffPerson)
 W.observePendingSourceInquiries()
end
assert(#__finishes==beforeBodyBackoff and backoffPhase.sourceInquiry.nextRetryTick==7256,
 'repeated body observation reset terminal reconciliation backoff')
__terminalFailures=0 __tick=7256
assert(W.observePendingSourceInquiries()==1 and backoffPhase.sourceInquiry==nil
 and #__finishes==beforeBodyBackoff+1 and __finishes[#__finishes].body==nil,
 'restored body pending inquiry did not recover at its retained retry tick')
SAOJavaBridge.weekOnePollEntries=oldPoll
SAO.ProceduralPlanning.finishSourceSituationInquiry=oldFinish
return 'PASS'
'''

CONTROLS = [
    ("drop-private-offer", "and inquiry.planSourceSituationInquiry then",
     "and false then", "selected-route"),
    ("infer-arrival", "if dx * dx + dy * dy <= 1 then",
     "if true then", "not-yet-arrived"),
    ("drop-fresh-sight", "if not fresh and inquiry.lastObservationTick ~= tick then",
     "if false then", "fresh-observed-position"),
    ("drop-tick-poll", "        W.observePendingSourceInquiries()\n",
     "        -- source inquiry poll omitted\n", "fresh-observed-position"),
    ("borrow-rebound-body", "or not runtime or runtime.body ~= body or runtime.brain ~= brain",
     "or false", "rebind-interruption"),
    ("drop-deadline", "elseif tick >= inquiry.deadlineTick then",
     "elseif false then", "bounded-deadline"),
    ("clear-failed-terminal", "if ok and recorded == true then",
     "if result ~= 'observed' or ok and recorded == true then",
     "rebind-interruption"),
    ("same-tick-terminal-spin", "if result and inquiry.lastRevisionTick ~= tick and retryDue then",
     "if result and retryDue then", "rebind-interruption"),
    ("unbounded-terminal-retry", "if inquiry.reconciliationFailures >= 16 then",
     "if false then", "durable-terminal-failure"),
    ("drop-automatic-recovery", "inquiry.nextRetryTick = tick + 240\n                        phase.lastSourceInquiry = {",
     "inquiry.nextRetryTick = tick + 240\n                        pending[personId] = nil\n                        phase.lastSourceInquiry = {",
     "durable-terminal-failure"),
    ("ignore-unresolved-backoff", "or tick >= inquiry.nextRetryTick",
     "or true", "bounded-unresolved-backoff"),
    ("drop-admitted-queue", "        trackSourceInquiry(actorId)\n",
     "        -- admitted inquiry omitted from runtime queue\n", "bounded-churn-tail"),
    ("drop-round-robin", "        sourceInquiryHead = sourceInquiryQueue[personId].next\n",
     "        -- retain the same inquiry head\n", "bounded-churn-first-slice"),
    ("block-known-work-on-discovery", '    local discovered = pollKeys(pending, "SourceInquiryPersons", 16)\n',
     '    local discovered = pollKeys(pending, "SourceInquiryPersons", 16)\n    if not discovered then return 0 end\n',
     "unavailable-discovery-preserves-known-work"),
    ("retain-previous-world-queue", "    sourceInquiryBodies = {}\n    sourceInquiryQueue, sourceInquiryHead, sourceInquiryCount = {}, nil, 0\n",
     "    sourceInquiryBodies = {}\n", "rebind-discards-runtime-queue"),
    ("drop-observed-body-pending-admission", "            trackSourceInquiry(row.personId)\n",
     "            -- observed restored inquiry omitted from runtime scheduling\n", "restored-body-pending-admission"),
    ("drop-observed-body-durable-admission", "            inquiryStore.pendingSourceInquiryByPerson[row.personId] = true\n",
     "            -- observed restored inquiry omitted from durable pending map\n", "restored-body-pending-admission"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    inputs = [SOURCE, Path(__file__), ROOT / "tools/luacheck/LuaRun.java",
              ROOT / "tools/weekone_active_program_test.py",
              ROOT / "tools/weekone_companion_program_test.py",
              ROOT / "tools/weekone_continuity_test.py",
              GAME / "projectzomboid.jar", GAME / "stdlib.lua"]
    receipt = {"schema": "sao-weekone-source-inquiry-kahlua/1",
               "status": "INCOMPLETE",
               "inputs": {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                          for path in inputs}}
    out = args.out.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    def save():
        out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    save()
    with tempfile.TemporaryDirectory(prefix="sao-weekone-inquiry-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        built = subprocess.run([str(JDK / "javac.exe"), "-cp",
            str(GAME / "projectzomboid.jar"), "-d", str(work),
            str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True, timeout=120)
        assert built.returncode == 0, built.stderr
        source = SOURCE.read_text(encoding="utf-8")
        for name, content in (("prelude.lua", PRELUDE + PORTS + FIXTURE + SETUP),
                              ("sao.lua", source),
                              ("cases.lua", "function __cases()\n" + CASES +
                               "\nend\nfunction __safe() local ok,value=pcall(__cases)" +
                               " if ok then return value end return 'FAIL:'..tostring(__step)..':'..tostring(value) end")):
            (work / name).write_text(content, encoding="utf-8")
        receipt["runs"] = []
        for name, old, new, marker in [("production", None, None, None), *CONTROLS]:
            current = source
            if old:
                assert current.count(old) == 1, (name, current.count(old))
                current = current.replace(old, new, 1)
            (work / "sao.lua").write_text(current, encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                f"{GAME / 'projectzomboid.jar'};{work}", "LuaRun",
                str(work / "prelude.lua"), str(work / "sao.lua"),
                str(work / "cases.lua"), "--", "__safe()"],
                cwd=work, capture_output=True, text=True, timeout=60)
            output = done.stdout + done.stderr
            receipt["runs"].append({"name": name, "exit": done.returncode,
                                    "output": output[-3000:]})
            save()
            if marker:
                assert "VALUE FAIL:" + marker in done.stdout, (name, output)
            else:
                assert done.returncode == 0 and "VALUE PASS" in done.stdout, output
    receipt["inputsAfter"] = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                              for path in inputs}
    assert receipt["inputsAfter"] == receipt["inputs"], "inquiry proof inputs changed"
    receipt["status"] = "PASS"
    save()
    print(f"PASS Week One source inquiry dispatch, observation, rebind, deadline and {len(CONTROLS)} controls")


if __name__ == "__main__":
    main()
