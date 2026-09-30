#!/usr/bin/env python3
"""Border 214: installed reading actions advance private maintained study."""
from pathlib import Path
import os
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
STUDY = ROOT / "mod/42.20/media/lua/client/SAO_Study.lua"
PLANNER = ROOT / "mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua"
NEEDS = ROOT / "mod/42.20/media/lua/client/SAO_Needs.lua"
IDENTITY = ROOT / "mod/42.20/media/lua/shared/SAO_Identity.lua"
CONTROLLER = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"

PRELUDE = r'''
require=function() end
Events={OnInitGlobalModData={Add=function(f) __reset=f end}}
getText=function(s) return s end
getGameTime=function() return {getMultiplier=function() return 1 end,
    getMinutesPerDay=function() return 60 end} end
getSandboxOptions=function() return {getOptionByName=function()
    return {getValue=function() return 2 end} end} end
isClient=function() return false end
isServer=function() return false end
sendSyncPlayerFields=function() end
__nativeSyncCalls=0
syncItemFields=function() __nativeSyncCalls=__nativeSyncCalls+1 end
CharacterTrait={ILLITERATE='illiterate',FAST_READER='fast',SLOW_READER='slow'}
CharacterStat={UNHAPPINESS='unhappy'}
ItemTag={FAST_READ='fastread'}
ItemBodyLocation={EYES='eyes'}
ISLogSystem={logAction=function() end}
ISInventoryPage={}
function instanceof(item, kind) return item.kind==kind end
SkillBook={Cooking={perk={getId=function() return 'Cooking' end},
    maxMultiplier1=3}}
__records={a={id='a'},b={id='b'}}
ModData={getOrCreate=function(key)
    if key=='SurvivorAwareness_Records' then return {records=__records} end
    return {}
end}
__bodies={}
__hours=10
SAO={Log={line=function() end},Identity={get=function(id) return __records[id] end},
    Body={get=function(id) return __bodies[id] end},
    History={countyHours=function() return __hours end,
        literacyOf=function(id) return __records[id].literacy or 'reads' end},
    Census={JOB_PERK={cook='Cooking'}, bookSkillFor=function(p) return p end},
    Conditions={readingTime=function() return 1 end}}
function fixture(id)
    __records[id].forename,__records[id].surname='Test','Person'
    __records[id].x,__records[id].y=1,1
    local body={pages=0,level=0,multiplier=0,attached=true,
        data={SAOPersonId=id,SAOExternalToken='owner-1'}}
    local book={kind='Literature',pages=0,total=100,id=7,domain='Cooking',
        first=1,last=2,fullType='Base.BookCooking1'}
    local inv={item=book}
    function inv:contains(item) return self.item==item end
    function book:getContainer() return inv end
    function book:getID() return self.id end
    function book:getFullType() return self.fullType end
    function book:getSkillTrained() return self.domain end
    function book:getNumberOfPages() return self.total end
    function book:getAlreadyReadPages() return self.pages end
    function book:setAlreadyReadPages(p) self.pages=p end
    function book:getLvlSkillTrained() return self.first end
    function book:getMaxLevelTrained() return self.last end
    function book:hasTag() return false end
    function book:hasModData() return false end
    function book:getLearnedRecipes() return nil end
    function book:setJobDelta() end
    function body:getInventory() return inv end
    function body:getPlayerNum() return -1 end
    function body:isDead() return self.dead==true end
    function body:isExistInTheWorld() return self.attached end
    function body:getModData() return self.data end
    function body:getAlreadyReadPages() return self.pages end
    function body:setAlreadyReadPages(_,p) self.pages=p end
    function body:getPerkLevel() return self.level end
    function body:hasTrait(t) return t=='illiterate' and self.illiterate==true end
    function body:tooDarkToRead() return self.dark==true end
    function body:isTimedActionInstant() return false end
    function body:getWornItems() return {getItem=function() return nil end} end
    function body:isSitting() return false end
    function body:getVehicle() return nil end
    function body:getBodyDamage() return {} end
    function body:getStats() return {get=function() return 0 end} end
    function body:getXp() return {getMultiplier=function() return body.multiplier end} end
    function body:ReadLiterature() error('instant skill-book path was called') end
    function body:setReading() end
    function body:playSound() end
    function body:setIsFarming() end
    __bodies[id]=body
    return body,book,inv
end
addXpMultiplier=function(body,_,n) body.multiplier=n end
SAOJavaBridge={privateCarriedItems=function(_,body)
    local items=body:getInventory()
    return {size=function() return items.item and 1 or 0 end,
        get=function() return items.item end}
end}
ISTimedActionQueue={queues={},accept=true}
function ISTimedActionQueue.hasAction(action)
    local q=ISTimedActionQueue.queues[action.character]
    for _,member in ipairs(q and q.queue or {}) do
        if member==action then return true end
    end
    return false
end
function ISTimedActionQueue.clear(body)
    ISTimedActionQueue.queues[body]=nil
end
SAOJavaBridge.hasPendingActions=function(_,body)
    return ISTimedActionQueue.queues[body]~=nil
end
ISTimedActionQueue.add=function(action)
        if not ISTimedActionQueue.accept then return false end
        local q=ISTimedActionQueue.queues[action.character] or {queue={}}
        q.queue[#q.queue+1]=action
        q.action=q.queue[1]
        ISTimedActionQueue.queues[action.character]=q
end
'''

CASES = r'''
local result={}
local function check(k,v)
    result[#result+1]=k..'='..tostring(v==true)
    print(result[#result])
end
local S=SAO.Study
local a,book,inv=fixture('a')
check('undesignated_person_can_offer_owned_manual',S.offer('a',a)==book)
local savedBefore=__records.a.proceduralPlanning
check('offer_is_read_only',savedBefore==nil)
check('native_study_enters_verified_queue',S.begin('a',a,book))
local action=ISTimedActionQueue.queues[a].action
local purpose=__records.a.proceduralPlanning.purposes[action.purposeId]
check('native_duration_retained',action.maxTime==24000)
check('queue_admission_is_not_learning',purpose.sessions==nil and a.pages==0
    and a.multiplier==0 and purpose.cursor==1
    and SAO.ProceduralPlanning.readingSessions('a','Cooking')==0)
check('owned_queue_maintains_purpose',S.active('a',a))
action.action={getJobDelta=function() return 0.4 end}
action:update()
check('installed_update_records_native_pages',a.pages==40 and book.pages==40
    and a.multiplier>0)
check('progress_is_visible_without_completed_practice',S.snapshot('a').pages==40
    and SAO.ProceduralPlanning.techniqueProfile('a').practice.Cooking==nil)
S.interrupt('a',a,'heard close danger')
check('interruption_retains_pages_and_purpose',a.pages==40 and purpose.status=='interrupted'
    and __records.a.studyWork.status=='interrupted' and purpose.sessions==nil)
check('resumed_study_enters_same_purpose',S.begin('a',a,book)
    and __records.a.studyWork.purposeId==purpose.id)
action=ISTimedActionQueue.queues[a].action
check('native_resumption_uses_person_pages',action.startPage==40)
action.action={getJobDelta=function() return 1 end}
action:update()
check('completion_is_native_and_receipt_bound',action:complete()==true
    and a.pages==100 and book.pages==100 and purpose.sessions==1
    and __records.a.studyWork.status=='completed' and __nativeSyncCalls==1)
local profile=SAO.ProceduralPlanning.techniqueProfile('a').practice.Cooking
check('reading_does_not_claim_practical_skill',profile~=nil and profile.completed==0
    and profile.readingSessions==1 and a.level==0 and purpose.steps[2].verb=='practice')
check('observer_does_not_label_reading_as_practice',SAO.ProceduralPlanning.snapshot('a').practiceDomains==0)
action:complete()
check('duplicate_callback_does_not_repeat_learning',purpose.sessions==1)
ISTimedActionQueue.clear(a)
check('finished_book_is_not_repeated',S.offer('a',a)==nil)

SkillBook.Woodwork={perk={getId=function() return 'Woodwork' end},maxMultiplier1=3}
a,book,inv=fixture('a')
book.domain,book.fullType='Woodwork','Base.BookCarpentry1'
local secondStarted=S.begin('a',a,book)
action=ISTimedActionQueue.queues[a].action
action.action={getJobDelta=function() return 1 end}
action:update()
local secondCompleted=action:complete()
check('second_subject_preserves_prior_reading_history',secondStarted and secondCompleted
    and __records.a.studyWork.bookSkill=='Woodwork'
    and SAO.ProceduralPlanning.readingSessions('a','Cooking')==1
    and SAO.ProceduralPlanning.readingSessions('a','Woodwork')==1)
ISTimedActionQueue.clear(a)

local b,other,otherInv=fixture('b')
__records.b.literacy='none'
check('nonreader_cannot_study',S.offer('b',b)==nil and not S.begin('b',b,other))
__records.b.literacy='reads'
other.first=3
check('advanced_book_does_not_grant_competence',S.offer('b',b)==nil
    and not S.begin('b',b,other))
other.first=1
b.dark=true
check('darkness_blocks_admission',not S.begin('b',b,other))
b.dark=false
ISTimedActionQueue.accept=false
check('queue_refusal_has_no_credit',not S.begin('b',b,other)
    and __records.b.studyWork.status=='interrupted' and b.pages==0)
ISTimedActionQueue.accept=true
check('refused_work_can_be_replanned',S.begin('b',b,other))
local owner=ISTimedActionQueue.queues[b].action
b.data.SAOExternalToken='changed'
check('ownership_change_refuses_native_completion',owner:complete()==false
    and b.pages==0)
ISTimedActionQueue.clear(b)
b.data.SAOExternalToken='owner-1'
__records.b={id='b'}
b,other,otherInv=fixture('b')
S.begin('b',b,other)
owner=ISTimedActionQueue.queues[b].action
otherInv.item=nil
check('book_loss_refuses_native_completion',owner:complete()==false and b.pages==0)
ISTimedActionQueue.clear(b)
otherInv.item=other
__records.b={id='b'}
b,other,otherInv=fixture('b')
S.begin('b',b,other)
owner=ISTimedActionQueue.queues[b].action
owner.action={getJobDelta=function() return 0.3 end}
owner:update()
__reset()
check('reload_censors_missing_runtime_without_teaching',not S.active('b',b)
    and __records.b.studyWork.status=='interrupted' and b.pages==30)
check('reload_preserves_native_partial_progress_display',S.snapshot('b').pages==30)
__bodies.b=nil
check('dormant_interrupted_study_is_observable',S.snapshot('b').pages==30)
__bodies.b=b
ISTimedActionQueue.clear(b)
__records.b={id='b'}
b,other,otherInv=fixture('b')
S.begin('b',b,other)
owner=ISTimedActionQueue.queues[b].action
local bp=__records.b.proceduralPlanning.purposes[owner.purposeId]
bp.admission.correlationId='different-native-work'
owner.action={getJobDelta=function() return 1 end}
owner:update()
check('mismatched_admission_cannot_advance_purpose',owner:complete()==true
    and bp.sessions==nil)
ISTimedActionQueue.clear(b)
__records.b={id='b'}
b,other,otherInv=fixture('b')
S.begin('b',b,other)
local urgent={character=b}
check('new_native_work_retires_reading_before_queueing',SAO.Needs.queueVerified(urgent)
    and ISTimedActionQueue.queues[b].action==urgent
    and __records.b.studyWork.status=='interrupted')
S.interrupt('b',b,'immediate need')
local after=ISTimedActionQueue.queues[b]
check('late_interruption_preserves_urgent_action',after~=nil and after.action==urgent)
ISTimedActionQueue.clear(b)
__records.b={id='b'}
b,other,otherInv=fixture('b')
S.begin('b',b,other)
owner=ISTimedActionQueue.queues[b].action
b.dead=true
local person=__records.b
local deathRecorded=SAO.Identity.markDead(person,99,'test death')
check('death_retires_native_reading_without_deleting_person',deathRecorded
    and __records.b==person and person.dead
    and person.studyWork.status=='interrupted'
    and ISTimedActionQueue.queues[b]==nil)
check('late_dead_owner_cannot_teach',owner:complete()==false
    and SAO.ProceduralPlanning.readingSessions('b','Cooking')==0)
__records.b={id='b'}
b,other,otherInv=fixture('b')
SAO.Conditions.readingTime=function() return 1.25 end
local adjustedStarted=S.begin('b',b,other)
check('conditions_adjust_native_book_duration',adjustedStarted
    and ISTimedActionQueue.queues[b].action.maxTime==30000)
S.interrupt('b',b,'test boundary')
__records.b={id='b'}
b,other,otherInv=fixture('b')
__records.b.designation='cook'
b.dark=true
local admittedInDark=S.begin('b',b,other)
local waitingDetail=__studyRestDetail('b',{},b,5000,__records.b)
check('owned_manual_waits_without_false_missing_book_purpose',not admittedInDark
    and waitingDetail=='has a useful manual; cannot study it yet'
    and __records.b.proceduralPlanning==nil)
otherInv.item=nil
__studyRestDetail('b',{},b,5000,__records.b)
local missingPurpose
for _, candidate in pairs(__records.b.proceduralPlanning.purposes) do
    missingPurpose=candidate
end
check('actually_missing_manual_retains_private_prerequisite',missingPurpose~=nil
    and missingPurpose.steps[1].id=='locate-book')
__studyResults=table.concat(result,',')
'''

CONTROLS = [
    ("body-owner", "and action.character:getModData().SAOExternalToken == action.bodyToken", "",
     "ownership_change_refuses_native_completion"),
    ("held-item", "and held(action.character, action.item)", "",
     "book_loss_refuses_native_completion"),
    ("native-completion", "local result = ISReadABook.complete(self)", "local result = true",
     "completion_is_native_and_receipt_bound"),
    ("reading-time-factor", "action.maxTime = action.maxTime * math.max(0.25, tonumber(effort) or 1)",
     "action.maxTime = action.maxTime", "conditions_adjust_native_book_duration"),
]


def main():
    if not (GAME / "projectzomboid.jar").is_file() or not (JDK / "javac.exe").is_file():
        print("Border 214 SKIPPED: installed game VM and JDK absent")
        return 0
    source = STUDY.read_text(encoding="utf-8-sig")
    with tempfile.TemporaryDirectory(prefix="sao-study-") as directory:
        work = Path(directory)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        build = subprocess.run([str(JDK / "javac.exe"), "-cp", str(GAME / "projectzomboid.jar"),
            "-d", str(work), str(ROOT / "tools/luacheck/LuaRun.java")],
            capture_output=True, text=True)
        if build.returncode:
            print("FAULT study runner:", build.stderr)
            return 1
        for name, text in [("prelude.lua", PRELUDE), ("cases.lua", CASES)]:
            (work / name).write_text(text, encoding="utf-8")
        expected = set(re.findall(r"check\('([a-z0-9_]+)'", CASES))
        def run(text, needs=None, planner=None, identity=None, controller=None):
            (work / "study.lua").write_text(text, encoding="utf-8")
            (work / "needs.lua").write_text(needs or NEEDS.read_text(encoding="utf-8-sig"), encoding="utf-8")
            (work / "planner.lua").write_text(planner or PLANNER.read_text(encoding="utf-8-sig"), encoding="utf-8")
            (work / "identity.lua").write_text(identity or IDENTITY.read_text(encoding="utf-8-sig"), encoding="utf-8")
            controller = controller or CONTROLLER.read_text(encoding="utf-8-sig")
            start = "        elseif idleRec and idleRec.designation\n"
            end = "        -- [B32] Same lock as the porch above: on cooldown"
            if controller.count(start) != 1 or controller.count(end) != 1:
                raise RuntimeError("native study rest branch anchors differ")
            branch = controller.split(start, 1)[1].split(end, 1)[0]
            (work / "rest.lua").write_text(
                "function __studyRestDetail(id,agent,body,tick,idleRec)\n"
                "local detail=''; if idleRec and idleRec.designation\n" + branch
                + "end; return detail end\n", encoding="utf-8")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                str(work) + os.pathsep + str(GAME / "projectzomboid.jar"), "LuaRun",
                str(work / "prelude.lua"), str(GAME / "media/lua/shared/ISBaseObject.lua"),
                str(GAME / "media/lua/shared/TimedActions/ISBaseTimedAction.lua"),
                str(GAME / "media/lua/client/TimedActions/ISInventoryTransferAction.lua"),
                str(GAME / "media/lua/shared/TimedActions/ISReadABook.lua"),
                str(work / "identity.lua"), str(work / "planner.lua"), str(work / "needs.lua"),
                str(work / "study.lua"), str(work / "rest.lua"), str(work / "cases.lua"),
                "--", "__studyResults"], cwd=work, capture_output=True, text=True, timeout=60)
            checks = dict(re.findall(r"([a-z0-9_]+)=(true|false)", done.stdout))
            if done.returncode or set(checks) != expected:
                raise RuntimeError(done.stdout[-4000:] + done.stderr[-1000:])
            return checks
        try:
            checks = run(source)
            failures = [k for k, v in checks.items() if v != "true"]
            if failures:
                raise RuntimeError("study failures: " + ", ".join(failures))
            for name, before, after, target in CONTROLS:
                if source.count(before) != 1:
                    raise RuntimeError(name + ": mutation anchor differs")
                if run(source.replace(before, after, 1))[target] != "false":
                    raise RuntimeError(name + ": named mutation did not fail")
            needs = NEEDS.read_text(encoding="utf-8-sig")
            before = "if SAO.Study and SAO.Study.beforeQueue then SAO.Study.beforeQueue(action) end"
            if needs.count(before) != 1 or run(source, needs.replace(before, "", 1))[
                    "new_native_work_retires_reading_before_queueing"] != "false":
                raise RuntimeError("pre-admission-owner: named mutation did not fail")
            planner = PLANNER.read_text(encoding="utf-8-sig")
            before = "practice.readingSessions = (practice.readingSessions or 0) + 1"
            if planner.count(before) != 1 or run(source, planner=planner.replace(before,
                    "practice.readingSessions = 0", 1))[
                    "second_subject_preserves_prior_reading_history"] != "false":
                raise RuntimeError("retained-reading-history: named mutation did not fail")
            identity = IDENTITY.read_text(encoding="utf-8-sig")
            before = "pcall(SAO.Study.forget, rec.id)"
            if identity.count(before) != 1 or run(source, identity=identity.replace(before, "", 1))[
                    "death_retires_native_reading_without_deleting_person"] != "false":
                raise RuntimeError("death-cleanup: named mutation did not fail")
            controller = CONTROLLER.read_text(encoding="utf-8-sig")
            before = ('            elseif SAO.Study and SAO.Study.offer(id, body) then\n'
                      '                detail = "has a useful manual; cannot study it yet"\n')
            if controller.count(before) != 1 or run(source, controller=controller.replace(before, "", 1))[
                    "owned_manual_waits_without_false_missing_book_purpose"] != "false":
                raise RuntimeError("owned-manual-prerequisite: named mutation did not fail")
            print(f"Border 214 PASS: {len(checks)} installed-action checks; {len(CONTROLS)+4} named controls")
            return 0
        except Exception as error:
            print("FAULT Border 214:", error)
            return 1


if __name__ == "__main__":
    raise SystemExit(main())
