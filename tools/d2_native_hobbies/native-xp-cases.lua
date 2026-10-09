local count=0
local function check(name,value)count=count+1;assert(value,'D2_NATIVE_MEDITATION:'..name)end
local L=SAO.Leisure;local S=SAO.LeisureSkill
local function begin()
    local offer,why=L.offers('person',__body)
    assert(offer[1],'native offer absent:'..tostring(why))
    local ok,w=L.begin('person',__body,offer[1],'purpose:1');assert(ok,tostring(w));return w
end
__nativeFresh(true)
check('native_body_in_world',__body:isExistInTheWorld() and __body:isSitOnGround())
local w=begin();local action=__queued
local perk=Perks.Meditation;local before=__body:getXp():getXP(perk);local foreign=__other:getXp():getXP(perk)
action:perform();check('unstarted_source_no_XP',__body:getXp():getXP(perk)==before)
action:start();action:update();action:update()
local rec=__records.person;local request=L.skillRequest('person',w.sequence,1)
local receipt=S.receipt('person','SAO.Leisure',w.sequence,1)
check('joined_native_XP',receipt and receipt.status=='applied' and __body:getXp():getXP(perk)>before)
check('source_request_actor_bound',request and request.nativeProgress.sourceCallback=='update'
    and request.nativeProgress.actionStarted and request.nativeProgress.jobDelta==0 and request.perkName=='Meditation')
check('source_requested_amount_measured',receipt.amount==request.amount and receipt.appliedDelta>0 and receipt.beforeXP==before)
check('foreign_native_body_unchanged',__other:getXp():getXP(perk)==foreign)
local after=__body:getXp():getXP(perk)
check('duplicate_receiver_refused',not S.consume('person',__body,'SAO.Leisure',w.sequence,1) and __body:getXp():getXP(perk)==after)
rec.leisureSkillRequests[1].amount=999999
check('saved_request_tampering_refused',L.skillRequest('person',w.sequence,1).amount~=999999)
rec.leisureSkillRequests[1].nativeProgress.sourceCallback='forged'
check('private_source_callback_retained',L.skillRequest('person',w.sequence,1).nativeProgress.sourceCallback=='update')
__delta=.5;action:update();__delta=1;action:update();action:perform()
check('native_completion_and_XP',L.outcome('person',w.sequence).status=='completed'
    and __body:getXp():getXP(perk)>after)
after=__body:getXp():getXP(perk)
action:perform();action:stop()
check('terminal_callbacks_no_XP',__body:getXp():getXP(perk)==after and L.skillRequest('person',w.sequence,1)==nil)
local saved=__roundTrip(rec)
check('actual_native_receipts_durable',saved.leisureSkill.receipts['SAO.Leisure/1/1'].status=='applied')
local sequence=rec.leisureSkillRequestSequence
__body:getStats():set(CharacterStat.BOREDOM,15);w=begin();action=__queued;action:start();action:update();action:update()
local request=L.skillRequest('person',w.sequence,sequence+1)
local receipt=S.receipt('person','SAO.Leisure',w.sequence,sequence+1)
check('second_work_global_sequence',request and receipt and receipt.status=='applied' and request.sequence==sequence+1)
after=__body:getXp():getXP(perk)
__reloadMeditation()
check('reload_interrupts_actual_work',L.outcome('person',w.sequence).status=='interrupted')
check('reload_does_not_replay_XP',__body:getXp():getXP(perk)==after
    and not S.consume('person',__body,'SAO.Leisure',w.sequence,sequence+1))
__nativeFresh(true)
__sourceDrift=true
local offers=L.offers('person',__body);local admitted,why=L.begin('person',__body,offers[1],'purpose:1')
check('changed_source_refused',not admitted and why:find('source%-revision%-changed') and not __queued
    and __body:getXp():getXP(perk)==0)
__nativeFresh(true)
w=begin();action=__queued;action:start();action:update()
after=__body:getXp():getXP(perk);local stress=__body:getStats():get(CharacterStat.STRESS)
__admit=false;action:update()
check('lost_purpose_no_XP',__body:getXp():getXP(perk)==after and __records.person.leisureSkillRequestSequence==nil)
check('lost_purpose_no_source_effect',__body:getStats():get(CharacterStat.STRESS)==stress)
check('lost_purpose_cleans_native_source',L.outcome('person',w.sequence).status=='interrupted'
    and __body:getModData().IsMeditating==false and __queued==nil)
__nativeFresh(true)
w=begin();action=__queued;action:start();action:update();action:update();after=__body:getXp():getXP(perk)
check('single_actor_interrupt',L.interrupt('person',__body,'native-interrupt')
    and L.outcome('person',w.sequence).reason=='native-interrupt' and __queued==nil)
action:update();action:perform();action:stop()
check('interrupted_request_retired',L.skillRequest('person',w.sequence,1)==nil and __body:getXp():getXP(perk)==after)
__nativeFresh(true);__body:setPerkLevelDebug(perk,10)
check('actual_native_mastery_level',__body:getPerkLevel(perk)==10)
w=begin();action=__queued;action:start();action:update();action:update();after=__body:getXp():getXP(perk)
check('mastered_source_zero_noop',L.work('person') and __records.person.leisureSkillRequestSequence==nil
    and after==0 and __body:getStats():get(CharacterStat.STRESS)<.8)
__delta=.5;action:update();__delta=1;action:update();action:perform()
check('mastered_source_completion_without_XP',L.outcome('person',w.sequence).status=='completed'
    and __body:getXp():getXP(perk)==after and __records.person.leisureSkillRequestSequence==nil)
__body:setPerkLevelDebug(perk,0)
__nativeFresh(true)
w=begin();action=__queued;action:start();action:update();action:update()
after=__body:getXp():getXP(perk);stress=__body:getStats():get(CharacterStat.STRESS)
local follower={id='following-native-action'};__follower=follower
check('foreign_detach_refused',not L.detach('person',__other,'foreign') and __queued==action)
__body:setHealth(0)
check('actual_native_body_death',__body:isDead())
check('dead_source_retired',L.detach('person',__body,'native-death')
    and L.outcome('person',w.sequence).status=='interrupted' and not L.outcome('person',w.sequence).afterCurrent)
check('dead_source_preserves_follower',__queued==follower and not __body:getModData().IsMeditating)
action:update();action:perform();action:stop()
check('dead_callbacks_no_native_effect',__body:getXp():getXP(perk)==after
    and __body:getStats():get(CharacterStat.STRESS)==stress and L.skillRequest('person',w.sequence,1)==nil)
__queued=nil;__nativeFresh(true)
w=begin();action=__queued;action:start();action:update();__follower=follower;__admit=false
check('retired_purpose_detach_cleans_only_own_action',L.detach('person',__body,'purpose-retired')
    and __queued==follower and L.outcome('person',w.sequence).status=='interrupted')
__queued=nil
print('PASS native meditation XP '..count)
