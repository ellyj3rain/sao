#!/usr/bin/env python3
"""Border 214: installed reading actions advance private maintained study."""
from pathlib import Path
import os
import argparse
import hashlib
import json
from datetime import datetime, timezone
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
GESTURE = ROOT / "mod/42.20/media/lua/client/SAO_Gesture.lua"
STUDY = ROOT / "mod/42.20/media/lua/client/SAO_Study.lua"
PLANNER = ROOT / "mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua"
NEEDS = ROOT / "mod/42.20/media/lua/client/SAO_Needs.lua"
IDENTITY = ROOT / "mod/42.20/media/lua/shared/SAO_Identity.lua"
CONTROLLER = ROOT / "mod/42.20/media/lua/client/SAO_Controller.lua"

PRELUDE = r'''
require=function() end
Events={OnInitGlobalModData={Add=function(f) __reset=f end},OnTick={Add=function(f) __gestureTick=f end}}
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
CharacterStat={UNHAPPINESS='unhappy',BOREDOM='bored',STRESS='stress'}
CharacterActionAnims={Read='Read'}
sendServerCommand=function() end
ItemTag={FAST_READ='fastread',UNINTERESTING='uninteresting',HARMONICA='harmonica'}
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
__agents={}
__hours=10
SAO={Hash={of=function() return 1 end},Log={line=function() end},Identity={get=function(id) return __records[id] end},
    Body={active=__bodies,foreign={},get=function(id) return __bodies[id] end},
    Controller={agents=__agents},
    Standing={groupOf=function() return nil end},
    Lessons={has=function() return false end},
    Disposition={isSmoker=function() return false end,traits=function() return {discipline=0.5} end},
    History={countyHours=function() return __hours end,
        literacyOf=function(id) return __records[id].literacy or 'reads' end},
    Census={JOB_PERK={cook='Cooking'}, bookSkillFor=function(p) return p end},
    Conditions={readingTime=function() return 1 end},
    -- This receiver fixture holds interpretation fixed; the dedicated leisure
    -- choice proof exercises actual Cognition/Models and learned alternatives.
    Cognition={interpretPlans=function(_,candidates) return {selected=candidates[1].id} end}}
function fixture(id)
    __records[id].forename,__records[id].surname='Test','Person'
    __records[id].x,__records[id].y=1,1
    __records[id].bodyOwnerToken='owner-1'
    __agents[id]={rec=__records[id]}
    local body={pages=0,level=0,multiplier=0,attached=true,
        data={SAOPersonId=id,SAOExternalToken='owner-1'}}
    local book={kind='Literature',pages=0,total=100,id=7,domain='Cooking',
        first=1,last=2,fullType='Base.BookCooking1'}
    local inv={item=book}
    function inv:contains(item) return self.item==item end
    function inv:setDrawDirty() body.dirtyCalls=(body.dirtyCalls or 0)+1 end
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
    function book:canBeWrite() return false end
    function book:hasModData() return self.data~=nil end
    function book:getModData() return self.data end
    function book:getName() return self.fullType end
    function book:getType() return 'Book' end
    function book:getReadType() return nil end
    function book:getUnhappyChange() return 0 end
    function book:setJobType() end
    function book:getLearnedRecipes() return nil end
    function book:setJobDelta() end
    function body:getInventory() return inv end
    function body:getPlayerNum() return -1 end
    function body:getX() return 1 end
    function body:getY() return 1 end
    function body:getZ() return 0 end
    function body:getOnlineID() return -1 end
    function body:isAsleep() return self.asleep==true end
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
    function body:isCanShout() return true end
    function body:getCharacterActions()
        return {isEmpty=function() return true end,contains=function() return false end}
    end
    body.emitter={isPlaying=function() return false end,stopSound=function() end}
    function body:getEmitter() return self.emitter end
    function body:getBodyDamage() return {} end
    function body:getStats() return {get=function() return 0 end} end
    function body:getXp() return {getMultiplier=function() return body.multiplier end} end
    function body:ReadLiterature(item)
        if SkillBook[item.domain] then error('instant skill-book path was called') end
        self.literatureEffects=(self.literatureEffects or 0)+1
    end
    function body:isLiteratureRead(title) return self.readTitle==title end
    function body:addReadLiterature(title) self.readTitle=title end
    function body:setReading(value) self.reading=value end
    function body:isReading() return self.reading==true end
    function body:reportEvent(event) self.event=event end
    function body:playSound() end
    function body:setIsFarming() end
    __bodies[id]=body
    return body,book,inv
end
addXpMultiplier=function(body,_,n) body.multiplier=n end
__leisureEffects=0
addSound=function() __leisureEffects=__leisureEffects+1 end
SAO.Standing.adjustTrust=function() __leisureEffects=__leisureEffects+1 end
SAOJavaBridge={steady=function() __leisureEffects=__leisureEffects+1 end,
    easeListeners=function() __leisureEffects=__leisureEffects+1 return 1 end,isShell=function() return true end,privateCarriedItems=function(_,body)
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
function ISTimedActionQueue.getTimedActionQueue(body)
    return {onCompleted=function() ISTimedActionQueue.queues[body]=nil end,
        resetQueue=function() ISTimedActionQueue.queues[body]=nil end}
end
function ISTimedActionQueue.clear(body)
    ISTimedActionQueue.queues[body]=nil
end
function native(action, delta)
    action.action={getJobDelta=function() return delta end,
        setCurrentTime=function() end,setActionAnim=function(_,name) action.nativeAnim=name end,
        setAnimVariable=function() end,setOverrideHandModelsObject=function(_,a,b) action.nativeHeld=b end,
        forceStop=function() action:forceCancel() end}
    action:start()
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
native(action,0.4)
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
native(action,1)
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
native(action,1)
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
native(owner,1);owner:update()
b.data.SAOExternalToken='changed'
__records.b.bodyOwnerToken='changed'
check('ownership_change_refuses_native_completion',owner:complete()==false
    and b.pages==100)
ISTimedActionQueue.clear(b)
b.data.SAOExternalToken='owner-1'
__records.b.bodyOwnerToken='owner-1'
__records.b={id='b'}
b,other,otherInv=fixture('b')
S.begin('b',b,other)
owner=ISTimedActionQueue.queues[b].action
otherInv.item=nil
check('eligibility_refuses_missing_exact_item',not S.readingEligibility('b',b,other,'study'))
otherInv.item=other
native(owner,1);owner:update()
otherInv.item=nil
check('book_loss_refuses_native_completion',owner:complete()==false and b.pages==100)
ISTimedActionQueue.clear(b)
otherInv.item=other
__records.b={id='b'}
b,other,otherInv=fixture('b')
S.begin('b',b,other)
owner=ISTimedActionQueue.queues[b].action
native(owner,0.3)
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
native(owner,1)
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

__records.b={id='b',reading='Base.BookFancy'}
b,other,otherInv=fixture('b')
other.domain,other.fullType,other.total='', 'Base.BookFancy', -1
other.data={literatureTitle='A novel'}
check('recreation_uses_exact_current_material',S.offerLeisure('b',b)==other)
local leisureAgent={}
check('controller_admits_real_reading_and_holds_turn',__restActivity('b',leisureAgent,b,9000,__records.b)==true
    and leisureAgent.pressure.phase=='preparing'
    and not string.find(leisureAgent.pressure.detail,'wall',1,true))
owner=ISTimedActionQueue.queues[b].action
local leisurePurpose=__records.b.proceduralPlanning.purposes[owner.purposeId]
check('recreation_queue_is_not_execution_or_effect',S.snapshot('b').phase=='preparing'
    and __records.b.studyWork.phase=='preparing'
    and S.describe('b')=='prepares to read carried literature' and b.literatureEffects==nil
    and leisurePurpose.cursor==2)
native(owner,0)
owner:update()
check('native_start_without_progress_remains_preparing',S.snapshot('b').phase=='preparing'
    and b.event=='EventRead' and owner.nativeAnim=='Read' and owner.nativeHeld==other)
owner.action.getJobDelta=function() return 0.4 end
owner:update()
check('native_progress_is_execution_without_completion',S.snapshot('b').phase=='executing'
    and S.snapshot('b').progress==0.4 and b.literatureEffects==nil and leisurePurpose.cursor==2)
local interruptedOwner=owner
S.interrupt('b',b,'noise')
check('interrupted_leisure_has_no_native_effect_or_result',b.literatureEffects==nil
    and S.snapshot('b').phase=='interrupted' and leisurePurpose.cursor==2)
check('interrupted_leisure_retains_purpose',S.beginLeisure('b',b,other)
    and __records.b.studyWork.purposeId==leisurePurpose.id)
owner=ISTimedActionQueue.queues[b].action
native(owner,1);owner:update()
interruptedOwner:stop()
check('superseded_stop_cannot_clear_new_reader',ISTimedActionQueue.queues[b]
    and ISTimedActionQueue.queues[b].action==owner and b:isReading()
    and S.active('b',b))
check('native_leisure_completion_is_exact_once',owner:complete()==true and b.literatureEffects==1
    and leisurePurpose.cursor==3 and S.snapshot('b').phase=='completed')
owner:complete()
check('leisure_cannot_create_skill_book_credit',b.literatureEffects==1
    and SAO.ProceduralPlanning.readingSessions('b','Cooking')==0 and b.level==0)
ISTimedActionQueue.clear(b)
check('read_title_is_not_offered_as_new',S.offerLeisure('b',b)==nil)

__records.b={id='b',reading='Base.BookFancy'}
b,other,otherInv=fixture('b')
other.domain,other.fullType,other.total='', 'Base.BookFancy', -1
otherInv.item=nil
local missingAgent={}
check('stale_reading_hint_has_no_action_or_posture_claim',__restActivity('b',missingAgent,b,10000,__records.b)==false
    and missingAgent.pressure.phase=='intended' and string.find(missingAgent.pressure.detail,'no unread carried',1,true)~=nil
    and __records.b.studyWork==nil and ISTimedActionQueue.queues[b]==nil)
otherInv.item=other
other.data={printMedia={id='paper'}}
check('human_print_media_ui_is_not_opened_for_offslot_reader',S.offerLeisure('b',b)==nil
    and not S.beginLeisure('b',b,other))
other.data=nil
b.dark=true
check('leisure_respects_native_darkness',not S.beginLeisure('b',b,other))
b.dark=false;b.asleep=true
check('sleeping_body_cannot_begin_leisure',not S.beginLeisure('b',b,other))
b.asleep=false
ISTimedActionQueue.accept=false
check('leisure_queue_refusal_is_not_execution',not S.beginLeisure('b',b,other)
    and S.snapshot('b').phase=='interrupted' and b.literatureEffects==nil)
ISTimedActionQueue.accept=true
__hours=__hours+1/60+0.001 -- bounded exact-item refusal expires before this unrelated callback case
S.beginLeisure('b',b,other)
owner=ISTimedActionQueue.queues[b].action
check('premature_completion_cannot_apply_native_effect',owner:complete()==false and b.literatureEffects==nil)
ISTimedActionQueue.clear(b)
S.beginLeisure('b',b,other)
owner=ISTimedActionQueue.queues[b].action
native(owner,0.2);owner:update()
check('partial_progress_cannot_complete_native_effect',owner:complete()==false and b.literatureEffects==nil)
ISTimedActionQueue.clear(b)
__records.b={id='b',reading='Base.BookFancy'}
b,other,otherInv=fixture('b')
other.domain,other.fullType,other.total='', 'Base.BookFancy', -1
S.beginLeisure('b',b,other)
owner=ISTimedActionQueue.queues[b].action
native(owner,0.2);owner:update()
local retiredReader=owner
S.interrupt('b',b,'urgent action')
local urgentOther={character=b}
SAO.Needs.queueVerified(urgentOther)
retiredReader:perform()
check('retired_perform_preserves_unrelated_native_work',ISTimedActionQueue.queues[b]
    and ISTimedActionQueue.queues[b].action==urgentOther and b.literatureEffects==nil)
ISTimedActionQueue.clear(b)
S.beginLeisure('b',b,other)
owner=ISTimedActionQueue.queues[b].action
native(owner,0.2);owner:update()
b.data.SAOExternalToken='new-generation'
owner:update()
check('stale_generation_stops_before_more_native_progress',S.snapshot('b').phase=='interrupted'
    and b.literatureEffects==nil)
ISTimedActionQueue.clear(b)
b.data.SAOExternalToken='owner-1'
__records.b.bodyOwner='foreign'
check('foreign_owner_cannot_offer_material',S.offerLeisure('b',b)==nil)
__records.b.bodyOwner=nil
__bodies.b=nil
check('detached_body_cannot_offer_material',S.offerLeisure('b',b)==nil)
__bodies.b=b
__records.b.reading=nil;__records.b.keepsake='ring';otherInv.item=nil
local keepsakeAgent={}
check('keepsake_intention_grants_no_physical_effect',__restActivity('b',keepsakeAgent,b,12000,__records.b)==false
    and keepsakeAgent.pressure.phase=='intended'
    and keepsakeAgent.pressure.detail=='wants time with a keepsake; handling is not admitted'
    and __leisureEffects==0)


__records.b={id='b',reading='Base.BookFancy'}
b,other,otherInv=fixture('b')
other.domain,other.fullType,other.total='', 'Base.BookFancy', -1
other.data={literatureTitle='Another novel'}
S.beginLeisure('b',b,other)
owner=ISTimedActionQueue.queues[b].action
owner:perform()
check('premature_perform_cannot_mark_title_read',b.readTitle==nil and b.literatureEffects==nil)
S.active('b',b)
__records.b={id='b',reading='Base.BookFancy'}
b,other,otherInv=fixture('b')
other.domain,other.fullType,other.total='', 'Base.BookFancy', -1
other.data={literatureTitle='Another novel'}
S.beginLeisure('b',b,other)
owner=ISTimedActionQueue.queues[b].action
native(owner,0.6);owner:update()
b:setReading(false)
check('lost_native_reading_flag_is_not_current_execution',S.snapshot('b').phase~='executing')
b:setReading(true)
owner.action.getJobDelta=function() return 1 end;owner:update()
owner:perform()
check('installed_perform_then_complete_preserves_native_reading',owner:complete()==true
    and b.readTitle=='Another novel' and b.literatureEffects==1 and b.dirtyCalls==1)
owner:perform()
check('duplicate_perform_does_not_touch_queue_or_item_again',b.dirtyCalls==1)
__records.b={id='b',instrument='Base.Harmonica'}
b,other,otherInv=fixture('b');other.fullType='Base.Harmonica';other.kind='InventoryItem'
function other:getDisplayCategory() return 'Instrument' end
function other:hasTag(tag) return tag==ItemTag.HARMONICA end
function other:getShoutType() return 'BlowHarmonica' end
function other:getShoutMultiplier() return 0.5 end
local instrumentAgent={}
check('real_material_gesture_admission_is_preparation',__restActivity('b',instrumentAgent,b,13000,__records.b)==true
    and instrumentAgent.pressure.phase=='preparing'
    and (not __records.b.proceduralPlanning or SAO.ProceduralPlanning.snapshot('b').practiceDomains==0)
    and __leisureEffects==0)
owner=ISTimedActionQueue.queues[b].action
check('gesture_binds_exact_material',owner.requiredItem==other and owner:isValid())
otherInv.item=nil
check('instrument_loss_invalidates_admitted_gesture',not owner:isValid())
ISTimedActionQueue.clear(b)
local instrumentUrgent={character=b}
ISTimedActionQueue.add(instrumentUrgent)
owner:perform()
check('retired_instrument_perform_preserves_other_queue',ISTimedActionQueue.queues[b]
    and ISTimedActionQueue.queues[b].action==instrumentUrgent)
ISTimedActionQueue.clear(b);ISTimedActionQueue.add(instrumentUrgent)
owner:stop()
check('retired_instrument_stop_preserves_other_queue',ISTimedActionQueue.queues[b]
    and ISTimedActionQueue.queues[b].action==instrumentUrgent)
ISTimedActionQueue.clear(b);__gestureTick()
local missingInstrumentAgent={}
check('instrument_hint_without_material_cannot_act',__restActivity('b',missingInstrumentAgent,b,14000,__records.b)==false
    and ISTimedActionQueue.queues[b]==nil)
otherInv.item=other;ISTimedActionQueue.accept=false
local refusedInstrumentAgent={}
check('gesture_queue_refusal_is_not_admission',__restActivity('b',refusedInstrumentAgent,b,15000,__records.b)==false
    and refusedInstrumentAgent.pressure.phase=='refused'
    and __records.b.leisureDecision.status=='refused' and ISTimedActionQueue.queues[b]==nil)
ISTimedActionQueue.accept=true

-- Joined actual Controller -> Planning -> Gesture -> canonical outcome, with
-- the native sound/queue clock controlled here (native owner proof is separate).
__gestureTick()
__records.b={id='b'}
b,other,otherInv=fixture('b');other.fullType='Base.Harmonica';other.kind='InventoryItem'
function other:getDisplayCategory() return 'Instrument' end
function other:hasTag(tag) return tag==ItemTag.HARMONICA end
function other:getShoutType() return 'BlowHarmonica' end
function other:getShoutMultiplier() return 0.5 end
function b:getCharacterActions()
 return {isEmpty=function() return ISTimedActionQueue.queues[b]==nil end,
 contains=function(_,action)
  local q=ISTimedActionQueue.queues[b];return q and q.action.action==action or false
 end}
end
local playing=false
b.emitter={isPlaying=function() return playing end,stopSound=function() playing=false end}
function b:playSound(name) if name=='BlowHarmonica' then return 7 end end
getWorldSoundManager=function() return {addSound=function() return {} end} end
local joined={}
check('joined_instrument_plan_precedes_queue',__restActivity('b',joined,b,20000,__records.b)==true)
owner=ISTimedActionQueue.queues[b].action
local work=SAO.Gesture.instrumentWork('b')
local plan
for _,candidate in pairs(__records.b.proceduralPlanning.purposes) do if candidate.instrument then plan=candidate end end
check('joined_instrument_exact_work_admitted',plan.admission.correlationId==work.workId
 and plan.admission.sequence==work.sequence and plan.steps[2].status~='completed')
native(owner,1);owner.action.forceComplete=function() end
playing=true;owner:update();playing=false;owner:update();owner:perform()
check('joined_native_sound_result_advances_only_matching_perform',plan.steps[2].status=='completed'
 and plan.steps[3].status~='completed' and plan.admission==nil
 and SAO.Gesture.instrumentOutcome('b').soundEnded==true
 and SAO.ProceduralPlanning.snapshot('b').practiceDomains==0)
local priorPlan=plan
check('joined_completed_blow_allows_next_occurrence',__restActivity('b',joined,b,23000,__records.b)==true
 and SAO.Gesture.instrumentWork('b').sequence==2 and priorPlan.steps[3].status~='completed')
owner=ISTimedActionQueue.queues[b].action
ISTimedActionQueue.clear(b);__gestureTick()
local add=ISTimedActionQueue.add
local starts=0
ISTimedActionQueue.add=function(action)
 add(action);native(action,0);starts=starts+1
end
function b:playSound() return 0 end
joined={}
check('joined_inline_sound_failure_keeps_exact_interrupted_purpose',__restActivity('b',joined,b,27000,__records.b)==true
 and starts==1 and SAO.Gesture.instrumentOutcome('b').status=='interrupted')
local last=SAO.Gesture.instrumentOutcome('b')
local failedPlan
for _,candidate in pairs(__records.b.proceduralPlanning.purposes) do
 if candidate.lastAdmission and candidate.lastAdmission.correlationId==last.workId then failedPlan=candidate end
end
check('joined_inline_failure_releases_prepared_binding',failedPlan and not failedPlan.admission
 and failedPlan.steps[2].status~='completed' and failedPlan.status=='interrupted')
ISTimedActionQueue.clear(b);__gestureTick()
local beforeStart=starts
check('joined_foreign_purpose_cannot_start_sound',not SAO.Gesture.playInstrument('b',b,'harmonica','Base.Harmonica',other,'foreign-purpose')
 and starts==beforeStart and ISTimedActionQueue.queues[b]==nil)
ISTimedActionQueue.add=add
__studyResults=table.concat(result,',')
'''

CONTROLLER_CONTROLS = [
    ("unexecuted-instrument-effects", '            agent.nextTuneAt = tick + (admitted and 2400 or 300)',
     '            SAOJavaBridge:easeListeners(body, 12)\n            agent.nextTuneAt = tick + (admitted and 2400 or 300)',
     "real_material_gesture_admission_is_preparation"),
    ("unexecuted-keepsake-effects", '            agent.nextKeepsakeAt = tick + 3600',
     '            SAOJavaBridge:steady(body, 0.04)\n            agent.nextKeepsakeAt = tick + 3600',
     "keepsake_intention_grants_no_physical_effect"),
]
GESTURE_CONTROLS = [
    # Freeze03 retired the old public material stop seam. Restore its blanket
    # base stop at the current exact closure to retain the same foreign-queue check.
    ("material-queue-cleanup", 'local function stopGesture(self, work)\n    if not ownsMaterialQueue(self, work) then return end',
     'local function stopGesture(self, work)\n    do ISBaseTimedAction.stop(self); return end',
     "retired_instrument_stop_preserves_other_queue"),
    ("gesture-queue-refusal", 'ok = ok and ISTimedActionQueue.hasAction(action) == true', '',
     "gesture_queue_refusal_is_not_admission"),
    # Instrument validity now composes exact optional custody with Needs' native
    # capability/custody read; restoring unvalidated validity targets the new join.
    ("exact-carried-instrument", '            if self ~= action or not optionalOwner(self, work) or not baseValid(self) then return false end\n            local current = SAO.Needs.instrumentAvailable(id, body, requiredItem)\n            return current and current.sound == instrument.sound and current.radius == instrument.radius or false',
     '            return true', "instrument_loss_invalidates_admitted_gesture"),
]
CONTROLS = [
    ("retired-perform", '    if not ISTimedActionQueue.hasAction(self) then return end\n', '',
     "retired_perform_preserves_unrelated_native_work"),
    ("superseded-stop", 'if ownsQueue and live(self.personId, self.character)',
     'if live(self.personId, self.character)', "superseded_stop_cannot_clear_new_reader"),
    ("full-native-duration", '\n        or not self.action or self:getJobDelta() < 1', '',
     "partial_progress_cannot_complete_native_effect"),
    ("native-perform-progress", 'self.nativeStarted and (work.progress or 0) > 0 and held(self.character, self.item)\n        and self.action and self:getJobDelta() >= 1',
     'held(self.character, self.item)', "premature_perform_cannot_mark_title_read"),
    ("native-progress-before-effects", " or not self.nativeStarted\n        or (rec(self.personId).studyWork.progress or 0) <= 0\n        or not self.action or self:getJobDelta() < 1", "",
     "premature_completion_cannot_apply_native_effect"),
    ("queue-is-preparation", 'phase = "preparing", progress = 0', 'phase = "executing", progress = 1',
     "recreation_queue_is_not_execution_or_effect"),
    ("observed-native-reading", 'if not self.nativeStarted or not self.character:isReading() then return end',
     'if true then return end', "native_progress_is_execution_without_completion"),
    ("canonical-owner", 'and SAO.Needs.ownsRecoveryBody(id, body)', '',
     "foreign_owner_cannot_offer_material"),
    ("body-owner", "and action.character:getModData().SAOExternalToken == action.bodyToken", "",
     "ownership_change_refuses_native_completion"),
    # Action custody is now also enforced by the common eligibility contract;
    # restore that omission directly while retaining the old callback check.
    ("held-item", '    if not held(body, item) then return false, "reading-item-not-held" end\n', "",
     "eligibility_refuses_missing_exact_item"),
    ("native-completion", "local result = ISReadABook.complete(self)", "local result = true",
     "completion_is_native_and_receipt_bound"),
    ("reading-time-factor", "action.maxTime = action.maxTime * math.max(0.25, tonumber(effort) or 1)",
     "action.maxTime = action.maxTime", "conditions_adjust_native_book_duration"),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--receipt')
    parser.add_argument('--production-only', action='store_true')
    parser.add_argument('--controls', nargs='+')
    args = parser.parse_args()
    all_controls=[x[0] for x in CONTROLS+CONTROLLER_CONTROLS+GESTURE_CONTROLS]+[
        'pre-admission-owner','retained-reading-history','death-cleanup','owned-manual-prerequisite']
    selected=set(args.controls or all_controls) if not args.production_only else set()
    if not selected <= set(all_controls): raise SystemExit('unknown study control')
    inputs = [STUDY, GESTURE, PLANNER, NEEDS, IDENTITY, CONTROLLER, Path(__file__),
        GAME/'projectzomboid.jar', GAME/'media/lua/shared/TimedActions/ISReadABook.lua',
        GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',ROOT/'tools/luacheck/LuaRun.java']
    pins = {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs if p.exists()}
    receipt = {'at':datetime.now(timezone.utc).isoformat(), 'inputs':pins, 'status':'running',
        'runs':[], 'controlsRequested':[x for x in all_controls if x in selected], 'scope':'Production Study/Needs/Planning and extracted actual Controller rest function with installed native reading Lua; controlled body/queue/native job delta. No rendered animation or loaded-world claim.'}
    def save(status, **fields):
        receipt.update(status=status, **fields)
        receipt['changedInputs'] = [p for p,h in pins.items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
        if args.receipt:
            target=Path(args.receipt);target.parent.mkdir(parents=True,exist_ok=True)
            target.write_text(json.dumps(receipt,indent=2)+'\n')
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
        def run(text, needs=None, planner=None, identity=None, controller=None, gesture=None):
            (work / "study.lua").write_text(text, encoding="utf-8")
            (work / "gesture.lua").write_text(gesture or GESTURE.read_text(encoding="utf-8-sig"), encoding="utf-8")
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
            full_rest = controller.split("local function decideRestActivity(", 1)[1].split(
                "local function decideLocalResources(", 1)[0]
            with (work / "rest.lua").open("a", encoding="utf-8") as rest_file:
                participation = "function Ctl.proposeLeisureParticipation(" + controller.split(
                    "function Ctl.proposeLeisureParticipation(", 1)[1].split(
                    "local function decideRestActivity(", 1)[0]
                rest_file.write("\nlocal Ctl=SAO.Controller\n" + participation
                    + "\nlocal function fixtureRestActivity(" + full_rest
                    + "\nfunction __restActivity(id,agent,body,tick,rec) agent.rec=rec; return fixtureRestActivity(id,agent,body,tick,rec) end\n")
            done = subprocess.run([str(JDK / "java.exe"), "-cp",
                str(work) + os.pathsep + str(GAME / "projectzomboid.jar"), "LuaRun",
                str(work / "prelude.lua"), str(GAME / "media/lua/shared/ISBaseObject.lua"),
                str(GAME / "media/lua/shared/TimedActions/ISBaseTimedAction.lua"),
                str(GAME / "media/lua/client/TimedActions/ISInventoryTransferAction.lua"),
                str(GAME / "media/lua/shared/TimedActions/ISReadABook.lua"),
                str(work / "identity.lua"), str(work / "planner.lua"), str(work / "needs.lua"),
                str(work / "study.lua"), str(work / "gesture.lua"), str(work / "rest.lua"), str(work / "cases.lua"),
                "--", "__studyResults"], cwd=work, capture_output=True, text=True, timeout=60)
            checks = dict(re.findall(r"([a-z0-9_]+)=(true|false)", done.stdout))
            evidence = {'ordinal':len(receipt['runs']), 'exitCode':done.returncode, 'checks':checks,
                'stdoutSha256':hashlib.sha256(done.stdout.encode()).hexdigest(),
                'stderrSha256':hashlib.sha256(done.stderr.encode()).hexdigest()}
            if args.receipt:
                logs=Path(args.receipt).with_suffix('.logs');logs.mkdir(parents=True,exist_ok=True)
                path=logs / ('run-%02d.log' % evidence['ordinal'])
                path.write_text(done.stdout+done.stderr,encoding='utf-8')
                evidence['log']=str(path.resolve());evidence['logSha256']=hashlib.sha256(path.read_bytes()).hexdigest()
            receipt['runs'].append(evidence)
            save('running')
            if done.returncode or set(checks) != expected:
                raise RuntimeError(done.stdout[-4000:] + done.stderr[-1000:])
            return checks
        try:
            checks = run(source)
            failures = [k for k, v in checks.items() if v != "true"]
            if failures:
                raise RuntimeError("study failures: " + ", ".join(failures))
            if not args.production_only:
                for name, before, after, target in CONTROLS:
                    if name not in selected: continue
                    owner_source, tail = source, ""
                    note_marker = 'SAONoteReadAction = ISBaseTimedAction:derive("SAONoteReadAction")'
                    if name in {"observed-native-reading", "full-native-duration"} and note_marker in source:
                        owner_source, note_source = source.split(note_marker, 1)
                        tail = note_marker + note_source
                    if owner_source.count(before) != 1:
                        raise RuntimeError(name + ": mutation anchor differs")
                    if run(owner_source.replace(before, after, 1) + tail)[target] != "false":
                        raise RuntimeError(name + ": named mutation did not fail")
                controller_source = CONTROLLER.read_text(encoding="utf-8-sig")
                for name, before, after, target in CONTROLLER_CONTROLS:
                    if name not in selected: continue
                    if controller_source.count(before) != 1 or run(source, controller=controller_source.replace(before, after, 1))[target] != "false":
                        raise RuntimeError(name + ": named mutation did not fail")
                gesture_source = GESTURE.read_text(encoding="utf-8-sig")
                for name, before, after, target in GESTURE_CONTROLS:
                    if name not in selected: continue
                    if gesture_source.count(before) != 1 or run(source, gesture=gesture_source.replace(before, after, 1))[target] != "false":
                        raise RuntimeError(name + ": named mutation did not fail")
                needs = NEEDS.read_text(encoding="utf-8-sig")
                before = "if SAO.Study and SAO.Study.beforeQueue then SAO.Study.beforeQueue(action) end"
                if 'pre-admission-owner' in selected and (needs.count(before) != 1 or run(source, needs.replace(before, "", 1))[
                        "new_native_work_retires_reading_before_queueing"] != "false"):
                    raise RuntimeError("pre-admission-owner: named mutation did not fail")
                planner = PLANNER.read_text(encoding="utf-8-sig")
                before = "practice.readingSessions = (practice.readingSessions or 0) + 1"
                if 'retained-reading-history' in selected and (planner.count(before) != 1 or run(source, planner=planner.replace(before,
                        "practice.readingSessions = 0", 1))[
                        "second_subject_preserves_prior_reading_history"] != "false"):
                    raise RuntimeError("retained-reading-history: named mutation did not fail")
                identity = IDENTITY.read_text(encoding="utf-8-sig")
                before = "pcall(SAO.Study.forget, rec.id)"
                if 'death-cleanup' in selected and (identity.count(before) != 1 or run(source, identity=identity.replace(before, "", 1))[
                        "death_retires_native_reading_without_deleting_person"] != "false"):
                    raise RuntimeError("death-cleanup: named mutation did not fail")
                controller = CONTROLLER.read_text(encoding="utf-8-sig")
                before = ('            elseif SAO.Study and SAO.Study.offer(id, body) then\n'
                          '                detail = "has a useful manual; cannot study it yet"\n')
                if 'owned-manual-prerequisite' in selected and (controller.count(before) != 1 or run(source, controller=controller.replace(before, "", 1))[
                        "owned_manual_waits_without_false_missing_book_purpose"] != "false"):
                    raise RuntimeError("owned-manual-prerequisite: named mutation did not fail")
            save('passed', checks=checks, controls=len(selected))
            print(f"Border 214 PASS: {len(checks)} installed-action checks; {len(selected)} named controls")
            return 0
        except Exception as error:
            save('failed', error=str(error))
            print("FAULT Border 214:", error)
            return 1


if __name__ == "__main__":
    raise SystemExit(main())
