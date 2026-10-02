#!/usr/bin/env python3
"""Native feeding measurements and production Lua completion/retention controls.

Uses an isolated installed-engine cell and Kahlua. Queue, animation, identity
providers and the learning receiver are controlled; no game process or save.
An optional installed feed extension is read in place, never shipped or copied.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True

PRELUDE = r'''
require=function() end
local empty={onMount={add=function() end},onDismount={add=function() end}}
require=function() return empty end
Events={OnGameStart={Add=function(fn) __resetCare=fn end}}
ISLogSystem={logAction=function() end}
sendFeedAnimalFromHand=function() F.sent=F.sent+1 end
SAO={Animals={},Log={line=function() end},Body={active={},foreign={}},Controller={agents={}}}
SAO.History={countyHours=function() return F.now end}
SAO.Identity={get=function(id) return F.rec and id==F.rec.id and F.rec or nil end}
SAO.Body.get=function(id) return SAO.Body.active[id] or SAO.Body.foreign[id] end
SAO.Body.isTransitioning=function() return F.transition==true end
-- Exposed membership fixture for the native current-cell boundary; retained
-- square/existence alone deliberately remain true on the old-body controls.
getWorld=function()
    if F.worldAbsent then return nil end
    local function listed(member)
        return {contains=function(self,body)
            if F.membershipError then error('unsupported native membership read') end
            return body==F.body and member
        end}
    end
    return {getCell=function() return {
        getObjectList=function() return listed(F.worldMember~=false) end,
        getAddList=function() return listed(F.worldAddMember==true) end,
    } end}
end
SAO.Standing={mayTakeCurrent=function() return F.permission end}
SAO.Cognition={animalCareOutcome=function(id,row)
    if not F.learning then return false,'disabled' end
    local canonical=F.rec.animalCare and F.rec.animalCare.outcomes[1]
    if canonical~=row or row.actorId~=id or row.status~='completed' then return false end
    F.learned=F.learned+1 F.learnedRow=row return true
end}
SAOJavaBridge={}
function SAOJavaBridge:isShell(body) return body~=nil and body.shell==true end
function SAOJavaBridge:animalCareBeginFeed(body,animal,food)
    F.beginCalls=(F.beginCalls or 0)+1
    if not F.beginAccept then return '' end
    if F.saturated then return 'BUSY' end
    F.nextToken=F.nextToken+1 F.token='animal-feed/1/'..F.nextToken
    return F.token
end
function SAOJavaBridge:animalCarePrepareFeed(body,token,animal,food)
    F.prepareCalls=F.prepareCalls+1
    F.beforeAmount,F.beforeHunger=F.amount,F.hunger
    return F.prepareAccept
end
function SAOJavaBridge:animalCareFinishFeed(body,token,animal,food,completed)
    F.finishCalls=F.finishCalls+1
    local status=completed and F.amount<F.beforeAmount and F.hunger<F.beforeHunger and 'completed' or 'no-effect'
    return status..'@'..token..'@7@19@Base.ControlledFeed@uses@'..F.beforeAmount..'@'..F.amount..'@'..F.beforeHunger..'@'..F.hunger..'@'..(status=='completed' and 'native-feed-consumed' or 'native-feed-unmeasured')
end
function SAOJavaBridge:animalCareCancelFeed(body,token) F.cancelled=F.cancelled+1 end
function SAOJavaBridge:animalCareNear(body,radius) return 'piglet@7@1@0@0@0.4@0@0@1@1@0@0@0@1@1@1@0@1@0' end
function SAOJavaBridge:animalCareTarget() return F.animal end
function SAOJavaBridge:animalCareFeed() return F.food end
function SAOJavaBridge:animalCareWater() return nil end
function SAOJavaBridge:privateCarriedItems() return {size=function() return 0 end} end
ISTimedActionQueue={add=function(action)
    F.action=action F.queued=F.queued+1
    action.action={forceStop=function() action:stop() end}
end,getTimedActionQueue=function(body) return {resetQueue=function()
    if body==F.body then F.originalQueueResets=(F.originalQueueResets or 0)+1
    else F.foreignQueueResets=(F.foreignQueueResets or 0)+1 end
end,onCompleted=function() end} end}
function fixture()
    if SAO.Animals.resetCareForWorld then SAO.Animals.resetCareForWorld() end
    F={now=10,amount=1,hunger=.4,nextToken=0,beginAccept=true,prepareAccept=true,permission=true,
       learning=false,learned=0,feeds=0,sent=0,queued=0,prepareCalls=0,finishCalls=0,cancelled=0}
    F.rec={id='care-a'}
    F.data={SAOPersonId='care-a'}
    F.body={shell=true,getModData=function() return F.data end,
        isDead=function() return false end,isExistInTheWorld=function() return F.exists~=false end,
        getCurrentSquare=function() return {} end,getInventory=function() return {contains=function() return true end} end,
        isTimedActionInstant=function() return false end,faceThisObject=function() end,
        playSound=function() return 1 end,getEmitter=function() return {isPlaying=function() return false end} end,
        setIsFarming=function() end,getX=function() return 0 end,getY=function() return 0 end}
    F.animal={getX=function() return 1 end,getY=function() return 0 end,getAnimalID=function() return 7 end,
        getBehavior=function() return {setBlockMovement=function(self,value) F.movementBlocked=value end} end,isExistInTheWorld=function() return true end,
        getFeedByHandAnim=function() return 'AnimalLureLow' end,feedFromHand=function(self,body,food)
            F.feeds=F.feeds+1
            if not F.noConsumption then F.amount=0 end
            if not F.noNeedChange then F.hunger=.3 end
            if F.nativeError then error('controlled-native-failure') end
        end}
    F.food={getID=function() return 19 end,getFullType=function() return 'Base.ControlledFeed' end,
        getFluidContainer=function() return nil end}
    SAO.Body.active['care-a']=F.body
    SAO.Body.foreign['care-a']=nil
    SAO.Controller.agents['care-a']={rec=F.rec}
    return F.body,F.animal,F.food
end
'''

CASES = r'''
local checks={}
local function check(name,value) checks[#checks+1]=name..'='..tostring(value==true) end
-- Animation and queue providers are controlled, while installed action callbacks execute.
ISFeedAnimalFromHand.setActionAnim=function() end
ISFeedAnimalFromHand.setOverrideHandModels=function() end
local A=SAO.Animals
local function admitted()
    fixture() local result=A.care('care-a',F.body,3)
    return result,F.action
end
local function started()
    local result,action=admitted() action:start() return action
end
local function foreignOwner()
    F.rec.bodyOwner='ZAO' F.rec.bodyOwnerToken='foreign-token'
    F.data.SAOExternalOwner='ZAO' F.data.SAOExternalToken='foreign-token' F.data.ZAOOwned=true
    SAO.Body.active['care-a']=nil SAO.Body.foreign['care-a']=F.body
    SAO.Controller.agents['care-a']={rec=F.rec,passive=true,state='PASSIVE'}
end
local function nativeAction()
    local action=ISFeedAnimalFromHand:new(F.body,F.animal,F.food)
    action.action={forceStop=function() action:stop() end}
    return action
end
local result,action=admitted()
check('queue_admission_is_not_completion',result=='feed' and F.queued==1 and F.feeds==0 and F.learned==0 and F.rec.animalCare.outcomes[1]==nil)
action:start()
check('native_start_has_no_learning',F.feeds==0 and F.learned==0 and F.rec.animalCare.outcomes[1]==nil)
action:complete()
local state=F.rec.animalCare local row=state.outcomes[1]
check('installed_complete_calls_existing_physical_owner',F.feeds==1 and F.sent==1 and F.amount==0 and F.hunger==.3)
check('exact_completed_receipt_retained_until_ack',row and row.status=='completed' and row.actorId=='care-a' and row.position==1 and row.nativeToken==F.token and row.consumedAmount==1 and row.worldHours==10 and F.learned==0)
check('duplicate_callback_cannot_repeat_native_effect',action:complete()==false and F.feeds==1 and state.sequence==1)
check('disabled_learning_keeps_receipt',A.deliverCareOutcomes('care-a')==false and #state.outcomes==1)
F.now=20 F.learning=true
check('ack_delivers_original_private_time_once',A.deliverCareOutcomes('care-a') and F.learned==1 and F.learnedRow.worldHours==10 and #state.outcomes==0 and state.acknowledgedThrough==1)
check('receipt_retry_has_no_new_learning',A.deliverCareOutcomes('care-a') and F.learned==1)

action=started() action:stop()
check('interruption_never_consumes_or_learns',action:complete()==false and F.feeds==0 and F.learned==0 and #F.rec.animalCare.outcomes==0)
action=started() F.prepareAccept=false
check('precompletion_refusal_keeps_feed',action:complete()==false and F.feeds==0 and F.amount==1 and #F.rec.animalCare.outcomes==0)
action=started() F.noConsumption=true action:complete()
check('need_change_without_consumption_has_no_receipt',F.feeds==1 and F.hunger==.3 and #F.rec.animalCare.outcomes==0)
action=started() F.noNeedChange=true action:complete()
check('consumption_without_need_change_has_no_receipt',F.feeds==1 and F.amount==0 and #F.rec.animalCare.outcomes==0)
action=started() action.food={getID=function() return 19 end}
check('same_id_food_substitution_prevents_native_call',action:complete()==false and F.feeds==0 and F.amount==1)
action=started() action.animal={getAnimalID=function() return 7 end}
check('same_id_animal_substitution_prevents_native_call',action:complete()==false and F.feeds==0)
action=started()
action.animal={getAnimalID=function() return 7 end,getBehavior=function() return {
    setBlockMovement=function() F.foreignAnimalChanged=true end} end}
check('substituted_target_cleanup_releases_original_animal',action:complete()==false
    and F.movementBlocked==false and not F.foreignAnimalChanged and F.feeds==0)
action=started()
action.character={getModData=function() return {SAOPersonId='care-a'} end}
check('substituted_actor_cleanup_retires_original_queue',action:complete()==false
    and F.originalQueueResets==1 and not F.foreignQueueResets and F.movementBlocked==false and F.feeds==0)
action=started() F.rec.bodyOwner='foreign'
check('changed_body_owner_prevents_native_call',action:complete()==false and F.feeds==0)
action=started() SAO.Body.active['care-a']={}
check('replaced_body_prevents_native_call',action:complete()==false and F.feeds==0)
action=started() F.exists=false
check('removed_body_prevents_native_call',action:complete()==false and F.feeds==0)
action=started() F.permission=false
check('standing_revocation_prevents_native_call',action:complete()==false and F.feeds==0)
fixture() F.permission=false local denied=A.care('care-a',F.body,3) if F.action then F.action:start() end
check('standing_refusal_has_no_physical_effect',denied==nil and F.queued==0 and F.feeds==0 and F.action==nil)
action=started() A.forget('care-a')
check('body_forget_cancels_capture',action:complete()==false and F.feeds==0 and F.cancelled==1)
action=started() A.resetCareForWorld()
check('world_reset_cancels_capture',action:complete()==false and F.feeds==0 and F.cancelled==1)
action=started() F.nativeError=true local ok=pcall(function() action:complete() end)
check('native_error_preserved_without_successful_learning',not ok and F.feeds==1 and #F.rec.animalCare.outcomes==0)
fixture() A.care('care-a',F.body,3) F.saturated=true F.action:start() F.action:complete()
check('observer_saturation_preserves_physical_care',F.feeds==1 and F.learned==0 and #F.rec.animalCare.outcomes==0)
fixture() A.care('care-a',F.body,3) F.saturated=true F.action:start() A.resetCareForWorld()
check('world_reset_also_withholds_unobserved_busy_work',F.action:complete()==false and F.feeds==0)
fixture()
check('foreign_caller_cannot_admit_body_care',A.care('care-other',F.body,3)==nil and F.queued==0)
fixture() F.learning=false
for n=1,35 do
    F.amount=1 F.hunger=.4
    local row=ISFeedAnimalFromHand:new(F.body,F.animal,F.food)
    row.action={forceStop=function() row:stop() end} row:start() row:complete()
end
check('disabled_outbox_is_bounded_without_stalling_care',F.feeds==35 and #F.rec.animalCare.outcomes==32 and F.rec.animalCare.omittedOutcomes==3 and F.rec.animalCare.sequence==35)
fixture() F.body.shell=false F.body.getModData=function() return {} end
action=ISFeedAnimalFromHand:new(F.body,F.animal,F.food) action:start() action:complete()
check('ordinary_player_physical_owner_is_unchanged',F.feeds==1 and F.sent==1 and F.finishCalls==0 and F.rec.animalCare==nil)
fixture() foreignOwner() F.learning=true F.permission=false
action=nativeAction() action:start()
local foreignCompleted=action:complete()
check('authenticated_existing_foreign_feed_passes_without_sao_learning',foreignCompleted==true and F.feeds==1
    and F.sent==1 and F.amount==0 and F.hunger==.3 and F.learned==0 and F.rec.animalCare==nil
    and F.beginCalls==nil and F.prepareCalls==0 and F.finishCalls==0 and action.saoAnimalCareWork==nil)
check('foreign_duplicate_callback_has_no_second_native_effect',action:complete()==false and F.feeds==1 and F.sent==1)
fixture() foreignOwner() SAO.Controller.agents['care-a'].state='IDLE'
action=nativeAction() action:start()
check('foreign_passive_ownership_is_independent_of_sao_state_label',action:complete()==true
    and F.feeds==1 and F.beginCalls==nil and F.rec.animalCare==nil)
fixture() foreignOwner() F.worldMember=false
action=nativeAction()
check('foreign_world_membership_refuses_retained_old_body',F.body:isExistInTheWorld()
    and F.body:getCurrentSquare()~=nil and action:start()==false and action:complete()==false
    and F.feeds==0 and F.beginCalls==nil and F.rec.animalCare==nil)
fixture() foreignOwner()
action=nativeAction() action:start() F.worldMember=false
check('foreign_completion_revalidates_current_world_membership',action:complete()==false
    and F.feeds==0 and F.movementBlocked==false and F.originalQueueResets==1 and F.rec.animalCare==nil)
fixture() foreignOwner() F.worldMember=false F.worldAddMember=true
action=nativeAction() action:start()
check('foreign_current_native_add_list_is_legitimate',action:complete()==true and F.feeds==1
    and F.beginCalls==nil and F.prepareCalls==0 and F.finishCalls==0 and F.rec.animalCare==nil)
fixture() foreignOwner() F.worldAbsent=true
action=nativeAction()
check('foreign_absent_native_world_read_refuses',action:start()==false and F.feeds==0 and F.beginCalls==nil)
fixture() foreignOwner() F.membershipError=true
action=nativeAction()
check('foreign_unsupported_native_membership_read_refuses',action:start()==false and F.feeds==0 and F.beginCalls==nil)
fixture() foreignOwner() F.worldMember=false SAO.Body.unloaded={['care-a']=true}
action=nativeAction()
check('foreign_unload_journal_cannot_admit_physical_feed',action:start()==false and F.feeds==0 and F.beginCalls==nil)
SAO.Body.unloaded=nil
fixture() foreignOwner() F.data.SAOExternalToken='forged-token'
action=nativeAction()
check('mismatched_foreign_token_refuses_native_feed',action:start()==false and action:complete()==false
    and F.feeds==0 and F.rec.animalCare==nil and F.beginCalls==nil)
fixture() F.data.SAOExternalOwner='ZAO' F.data.SAOExternalToken='foreign-token' F.data.ZAOOwned=true
action=nativeAction()
check('forged_external_flag_without_canonical_foreign_owner_refuses',action:start()==false
    and F.feeds==0 and F.rec.animalCare==nil and F.beginCalls==nil)
fixture() foreignOwner() SAO.Body.foreign['care-a']={}
action=nativeAction()
check('foreign_registry_replacement_refuses_native_feed',action:start()==false and F.feeds==0 and F.beginCalls==nil)
fixture() foreignOwner() SAO.Controller.agents['care-a'].passive=false
action=nativeAction()
check('foreign_nonpassive_controller_refuses_native_feed',action:start()==false and F.feeds==0 and F.beginCalls==nil)
fixture() foreignOwner() F.rec.bodyOwner='unknown-owner' F.data.SAOExternalOwner='unknown-owner'
action=nativeAction()
check('unknown_foreign_owner_refuses_native_feed',action:start()==false and F.feeds==0 and F.beginCalls==nil)
fixture() foreignOwner()
action=nativeAction() action:start() F.rec.bodyOwnerToken='new-token' F.data.SAOExternalToken='new-token'
check('foreign_start_binding_cannot_be_relabelled',action:complete()==false and F.feeds==0 and F.rec.animalCare==nil)
fixture() foreignOwner()
action=nativeAction() action:start() A.resetCareForWorld()
check('foreign_pass_through_cannot_survive_world_reset',action:complete()==false and F.feeds==0 and F.rec.animalCare==nil)
action=started() foreignOwner()
check('admitted_sao_work_transfer_denies_original_actor',action:complete()==false and F.feeds==0
    and F.cancelled==1 and F.originalQueueResets==1 and F.movementBlocked==false
    and action.character==F.body and action.saoAnimalCareForeign==nil and #F.rec.animalCare.outcomes==0)
local queuedResult
queuedResult,action=admitted() foreignOwner()
check('queued_sao_admission_transfer_cannot_become_foreign_feed',queuedResult=='feed' and action:start()==false
    and action:complete()==false and F.feeds==0 and F.beginCalls==nil and F.originalQueueResets==1
    and action.saoAnimalCareForeign==nil)
queuedResult,action=admitted()
action.character={getModData=function() return {} end}
check('queued_sao_actor_substitution_cancels_original_admission',action:start()==false
    and action.character==F.body and F.originalQueueResets==1 and F.feeds==0 and F.beginCalls==nil)
fixture() F.learning=true
action=ISFeedAnimalFromHand:new(F.body,F.animal,F.food)
check('completion_without_native_start_refuses',action:complete()==false and F.feeds==0 and F.learned==0)
__animalCareResults=table.concat(checks,'\n')
'''

NATIVE_PRELUDE = r'''
local empty={onMount={add=function() end},onDismount={add=function() end}}
require=function() return empty end
Events={OnGameStart={Add=function() end}}
sendFeedAnimalFromHand=function() __nativeSend=(__nativeSend or 0)+1 end
ISLogSystem={logAction=function() end}
SAO={Animals={},Log={line=function() end},Body={active={['care-native']=__nativeBody},foreign={}},Controller={agents={}}}
local rec={id='care-native'}
__nativeCareRecord=rec
SAO.Identity={get=function(id) return id=='care-native' and rec or nil end}
SAO.History={countyHours=function() return 10 end}
SAO.Body.get=function(id) return SAO.Body.active[id] end
SAO.Body.isTransitioning=function() return false end
SAO.Controller.agents['care-native']={rec=rec}
SAO.Standing={mayTakeCurrent=function() return true end}
SAO.Cognition={animalCareOutcome=function(id,row)
    if not __nativeLearning then return false,'disabled' end
    assert(id=='care-native' and row==rec.animalCare.outcomes[1])
    __nativeLearned=(__nativeLearned or 0)+1 return true
end}
ISTimedActionQueue={getTimedActionQueue=function() return {resetQueue=function() end,onCompleted=function() end} end}
'''

NATIVE_CASES = r'''
ISFeedAnimalFromHand.setActionAnim=function() end
ISFeedAnimalFromHand.setOverrideHandModels=function() end
local action=ISFeedAnimalFromHand:new(__nativeBody,__nativeAnimal,__nativeFood)
action.action={forceStop=function() action:stop() end}
action:start()
assert(action.saoAnimalCareWork and not action.saoAnimalCareDenied,'real-native-start-not-captured')
assert(action:complete()==true,'real-native-completion-refused')
local s=__nativeCareRecord.animalCare local row=s and s.outcomes[1]
assert(row and row.status=='completed' and row.consumedAmount==1 and row.hungerDelta>0,'real-native-completion-not-measured')
assert(__nativeSend==1 and row.actorId=='care-native' and row.position==1,'real-native-receipt-binding')
assert(action:complete()==false and s.sequence==1 and __nativeSend==1,'real-native-repeat-not-withheld')
__nativeLearning=true
assert(SAO.Animals.deliverCareOutcomes('care-native') and __nativeLearned==1 and #s.outcomes==0,'real-native-private-ack-failed')
assert(SAO.Animals.deliverCareOutcomes('care-native') and __nativeLearned==1,'real-native-private-repeat')
__nativeCareIntegrated=true
'''


def raw(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command, cwd, log):
    result = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True, text=True, timeout=60)
    with log.open('x', encoding='utf-8') as stream:
        stream.write(result.stdout + '\nSTDERR\n' + result.stderr)
    return result


def main(argv=None):
    print('Border 229: Native animal feeding completion')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, default=Path(os.environ.get('PZ_GAME_DIR', 'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')))
    parser.add_argument('--feed-extension', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3422249642/mods/BabyAnimalFood/42.0'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--required', action='store_true', help='Fail when installed native/optional feed proof inputs are absent')
    args = parser.parse_args(argv)
    preflight_helper = ROOT / 'tools/native_proof_preflight.py'
    if not preflight_helper.is_file():
        print('FAILED animal-care completion: owned proof inputs absent: ' + str(preflight_helper))
        return 1
    from native_proof_preflight import presence, causal_controls
    owner = ROOT / 'java/src/com/sao/engine/SAOAnimalCare.java'
    lua = ROOT / 'mod/42.20/media/lua/client/SAO_Animals.lua'
    helpers = [ROOT / 'tools/luacheck/MovementCrossingProbe.java', ROOT / 'tools/animal_care_checks/AnimalCareProbe.java', ROOT / 'tools/luacheck/LuaRun.java']
    owned = [owner, lua, Path(__file__).resolve(), *helpers, ROOT / 'mod/42.20/media/java/SAO.jar', preflight_helper]
    game = args.game.resolve()
    configured = os.environ.get('JDK_BIN')
    jdk = Path(configured) if configured else Path(os.environ.get('JAVA_HOME', 'C:/Users/jleyv/Peanut Butter/JetBrains/Java')) / 'bin'
    java = jdk / ('java.exe' if os.name == 'nt' else 'java')
    javac = jdk / ('javac.exe' if os.name == 'nt' else 'javac')
    if not java.is_file() or not javac.is_file():
        found = shutil.which('java'), shutil.which('javac')
        if all(found): java, javac = map(Path, found)
    feeds = args.feed_extension.resolve() / 'media/scripts/BabyAnimalFood_items.txt'
    definitions = args.feed_extension.resolve() / 'media/lua/shared/Definitions/animal/BabyAnimalDifinitions.lua'
    installed = [game / 'projectzomboid.jar', game / 'ZombieBuddy.jar', java, javac, feeds, definitions,
        game / 'media/lua/shared/ISBaseObject.lua', game / 'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
        game / 'media/lua/shared/TimedActions/Animals/ISFeedAnimalFromHand.lua', game / 'stdlib.lua']
    unavailable = presence(owned, installed, args.required, 'animal-care completion')
    if unavailable is not None:
        return unavailable
    stamp = datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
    output = args.output or ROOT / '_scratch/animal-care' / ('proof-' + stamp)
    output = output.absolute()
    if output.exists() or output.is_symlink() or output.resolve() != output:
        raise RuntimeError('Output exists or has an aliased path')
    allowed = ROOT.resolve() / '_scratch/animal-care'
    if not output.resolve().is_relative_to(allowed):
        raise RuntimeError('Output must be under the owned ignored animal-care directory')
    sources = [*owned, *installed]
    pins = {str(path): raw(path) for path in sources}
    output.mkdir(parents=True)
    classification = causal_controls(ROOT, Path(__file__), owned,
        child_args=('--game', '{absent-engine}', '--feed-extension', '{absent-extension}'), missing_owned=owner)
    cp = os.pathsep.join(map(str, [game / 'projectzomboid.jar', game / 'ZombieBuddy.jar', ROOT / 'mod/42.20/media/java/SAO.jar']))
    native_controls = [
        ('consume-and-need', 'c.amount - after > EPSILON && c.hunger - hunger > EPSILON', 'c.amount - after > EPSILON || c.hunger - hunger > EPSILON', 'hunger_change_without_exact_consumption_refuses_success'),
        ('exact-item', 'c.item.get() == food', 'true', 'same_id_replacement_item_refuses'),
        ('body-removal', 'body instanceof SAOIsoPlayerShell shell && shell.removalPending', 'false', 'pending_body_removal_refuses'),
        ('baseline', 'c.hunger = animal.getHunger();', '// restored stale admission baseline', 'earlier_need_change_does_not_complete'),
        ('definition-membership', '!physical(body, animal) || !accepts(body, animal, food)', '!physical(body, animal) || false', 'unknown_extension_feed_refuses'),
        ('world-reset', 'PENDING.clear(); epoch++;', 'epoch++;', 'world_reset_invalidates_existing_token'),
        ('pending-capacity', 'MAX_PENDING = 128', 'MAX_PENDING = 129', 'native_capacity_saturation_is_explicit_busy'),
    ]
    lua_controls = [
        ('care-admission-standing', 'if rank and kind and carePositionPermission(id, animal.x, animal.y) then', 'if rank and kind then', 'standing_refusal_has_no_physical_effect'),
        ('substitution-cleanup', 'action.character, action.animal, action.food = original.body, original.animal, original.item', '', 'substituted_target_cleanup_releases_original_animal'),
        ('foreign-token', '\n        or data.SAOExternalToken ~= rec.bodyOwnerToken', '', 'mismatched_foreign_token_refuses_native_feed'),
        ('foreign-world', 'if not cell or (not cell:getObjectList():contains(body)\n        and not cell:getAddList():contains(body)) then return nil end', 'if false then return nil end', 'foreign_world_membership_refuses_retained_old_body'),
        ('transferred-work', 'careOwner(work.id, self.character) ~= work.rec or ', '', 'admitted_sao_work_transfer_denies_original_actor'),
        ('queued-transfer', 'if admission then', 'if false then', 'queued_sao_admission_transfer_cannot_become_foreign_feed'),
        ('queue-learning', 'log(id .. " queued " .. best.kind .. " for " .. best.animal.type)', 'SAO.Cognition.animalCareOutcome(id, {status="completed"})\n        log(id .. " queued " .. best.kind .. " for " .. best.animal.type)', 'queue_admission_is_not_completion'),
        ('duplicate-native', 'if self.saoAnimalCareDenied or self.saoAnimalCareSettled then return false end', 'if self.saoAnimalCareDenied then return false end', 'duplicate_callback_cannot_repeat_native_effect'),
        ('permission', 'or not carePermission(work.id, work.animal) then return false end', 'then return false end', 'standing_revocation_prevents_native_call'),
        ('receipt-time', 'A.deliverCareOutcomes(work.id)', 'row.worldHours = row.worldHours + 1\n    A.deliverCareOutcomes(work.id)', 'exact_completed_receipt_retained_until_ack'),
        ('unobserved-world-reset', 'work.epoch ~= A.careEpoch or ', '', 'world_reset_also_withholds_unobserved_busy_work'),
    ]
    observations = []
    native_text, lua_text = owner.read_text(encoding='utf-8'), lua.read_text(encoding='utf-8')
    with tempfile.TemporaryDirectory(prefix='sao-care-') as temp:
        work = Path(temp)
        shutil.copyfile(game / 'stdlib.lua', work / 'stdlib.lua')
        built = run([javac, '-encoding', 'UTF-8', '-cp', cp, '-d', work, owner, *helpers], work, output / 'compile.log')
        if built.returncode: raise RuntimeError('Native compile failed: ' + built.stderr[-2500:])
        def native_run(name, prefix=work):
            return run([java, '-Duser.home=' + str(work), '-Djava.awt.headless=true', '--enable-native-access=ALL-UNNAMED',
                '-cp', str(prefix) + os.pathsep + str(work) + os.pathsep + cp, 'AnimalCareProbe', feeds, definitions], work, output / (name + '.log'))
        baseline = native_run('native-baseline')
        if baseline.returncode or 'ANIMAL_CARE_NATIVE_OK' not in baseline.stdout: raise RuntimeError(baseline.stdout[-3500:] + baseline.stderr[-2500:])
        native_count = len(re.findall(r'^CHECK .+=true$', baseline.stdout, re.M))
        native_prelude, native_cases = work / 'native-prelude.lua', work / 'native-cases.lua'
        native_prelude.write_text(NATIVE_PRELUDE, encoding='utf-8'); native_cases.write_text(NATIVE_CASES, encoding='utf-8')
        integrated = run([java, '-Duser.home=' + str(work), '-Djava.awt.headless=true', '--enable-native-access=ALL-UNNAMED',
            '-cp', str(work) + os.pathsep + cp, 'AnimalCareProbe', feeds, definitions, native_prelude, lua, native_cases], work, output / 'native-integrated.log')
        if integrated.returncode or 'installed_action_native_receiver_and_owned_wrapper_join=true' not in integrated.stdout:
            raise RuntimeError('Native integrated callback: ' + integrated.stdout[-4000:] + integrated.stderr[-2000:])
        integrated_count = len(re.findall(r'^CHECK .+=true$', integrated.stdout, re.M)) - native_count
        for name, before, after, expected in native_controls:
            if before not in native_text: raise RuntimeError(name + ': mutation anchor missing')
            directory = work / name; directory.mkdir()
            source = directory / 'SAOAnimalCare.java'; source.write_text(native_text.replace(before, after, 1), encoding='utf-8')
            built = run([javac, '-encoding', 'UTF-8', '-cp', cp, '-d', directory, source], work, output / (name + '-compile.log'))
            if built.returncode: raise RuntimeError(name + ': mutant compile failed: ' + built.stderr[-2000:])
            changed = native_run(name, directory)
            if changed.returncode == 0 or 'CHECK ' + expected + '=false' not in changed.stdout: raise RuntimeError(name + ': defect control did not fail at ' + expected)
            observations.append({'control': name, 'refusedAt': expected, 'exitCode': changed.returncode})
        prelude, cases = work / 'prelude.lua', work / 'cases.lua'
        prelude.write_text(PRELUDE, encoding='utf-8'); cases.write_text(CASES, encoding='utf-8')
        def lua_run(name, text):
            candidate = work / (name + '.lua'); candidate.write_text(text, encoding='utf-8')
            return run([java, '-cp', str(work) + os.pathsep + str(game / 'projectzomboid.jar'), 'LuaRun', prelude,
                game / 'media/lua/shared/ISBaseObject.lua', game / 'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
                game / 'media/lua/shared/TimedActions/Animals/ISFeedAnimalFromHand.lua', candidate, cases, '--', '__animalCareResults'], work, output / (name + '.log'))
        baseline = lua_run('lua-baseline', lua_text)
        checks = dict(re.findall(r'([a-z0-9_]+)=(true|false)', baseline.stdout))
        if baseline.returncode or len(checks) < 25 or 'false' in checks.values(): raise RuntimeError('Lua baseline failed: ' + baseline.stdout[-4500:] + baseline.stderr[-1500:])
        for name, before, after, expected in lua_controls:
            if before not in lua_text: raise RuntimeError(name + ': Lua anchor missing')
            if name == 'queue-learning':
                # A faulty receipt producer calls a permissive receiver during admission.
                altered = lua_text.replace(before, after, 1)
                # The fixture receiver records all calls, including invalid attempted admissions.
                prelude.write_text(PRELUDE.replace("if not F.learning then return false,'disabled' end", "if row.position==nil then F.learned=F.learned+1 return true end\n    if not F.learning then return false,'disabled' end"), encoding='utf-8')
            elif name in ('duplicate-native', 'unobserved-world-reset'):
                altered = lua_text.replace(before, after)
            else: altered = lua_text.replace(before, after, 1)
            changed = lua_run(name, altered)
            prelude.write_text(PRELUDE, encoding='utf-8')
            if changed.returncode == 0 and expected + '=false' not in changed.stdout: raise RuntimeError(name + ': Lua defect control did not flip ' + expected)
            if expected + '=false' not in changed.stdout: raise RuntimeError(name + ': failed for an unrelated reason: ' + changed.stdout[-2000:])
            observations.append({'control': name, 'refusedAt': expected, 'exitCode': changed.returncode})
    if any(raw(Path(path)) != digest for path, digest in pins.items()): raise RuntimeError('Frozen test input changed during checks')
    receipt = {'schema': 'sao-animal-care-completion-proof/1', 'sources': pins, 'nativeChecks': native_count,
        'integratedNativeChecks': integrated_count, 'luaChecks': len(checks), 'controls': observations,
        'preflight': classification, 'logs': {p.name: raw(p) for p in output.glob('*.log')},
        'limits': 'Installed native bodies/animals/item definitions/feed receiver and shared feed extension; production Lua and installed action callbacks with controlled queue/animation/identity/Standing/learning providers. No rendered gameplay, crafting execution, acquisition, save or model inference.'}
    with (output / 'receipt.json').open('x', encoding='utf-8') as stream: json.dump(receipt, stream, indent=2); stream.write('\n')
    print(f'PASS animal-care completion: {native_count}+{integrated_count} native checks, {len(checks)} installed Kahlua checks, {len(observations)} executing restored-defect controls')
    print('PREFLIGHT 3 CLI classification cases, missing-helper bootstrap, 1 executing owned-guard omission')
    print('Receipt:', output / 'receipt.json')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
