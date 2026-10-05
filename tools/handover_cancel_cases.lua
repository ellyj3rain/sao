-- Actual installed queue/base-action Lua; controlled inventory and native-stack witnesses.
SAO = { History={ticks=function()return 100 end}, Log={line=function()end} }
local stores, bodies, people = {}, {}, {}
local effects, stopped, nativeTransfers = 0, 0, 0
ModData={getOrCreate=function(key) stores[key]=stores[key] or {};return stores[key] end}
SAO.Body={get=function(id)return bodies[id]end}
SAO.Identity={get=function(id)return people[id]end}
SAO.Needs={ownsRecoveryBody=function(id,body)
    return bodies[id]==body and people[id] and people[id].bodyOwnerToken==body.data.SAOExternalToken
        and body.data.SAOExternalOwner==nil and body.data.ZAOOwned~=true
end,queueVerified=function(action) ISTimedActionQueue.add(action);return ISTimedActionQueue.hasAction(action)end}
SAO.Standing={adjustTrust=function()effects=effects+1 end}
SAOJavaBridge={isShell=function(_,body)return body.shell~=false end}
local function noop()end
removeItemTransaction=noop

-- The installed inventory class owns derive/stop/perform. Only the world-bound
-- inventory transfer and construction are controlled; no material game transfer is claimed.
function ISInventoryTransferAction:new(body,item,source,destination)
    local action=ISBaseTimedAction.new(self,body)
    action.item,action.sourceInventory,action.destinationInventory=item,source,destination
    action.srcContainer,action.destContainer=source,destination
    action.queueList={};return action
end
function ISInventoryTransferAction:begin()
    self.begins=(self.begins or 0)+1
    self.action={started=true,forced=false}
    function self.action:forceStop()self.forced=true;stopped=stopped+1 end
    function self.action:isStarted()return self.started end
    function self.action:setLoopedAction(value)self.loop=value end
    self.character.native[self.action]=true
end
function ISInventoryTransferAction:isValid()return self.item.container==self.sourceInventory end
function ISInventoryTransferAction:transferItem(item)
    nativeTransfers=nativeTransfers+1;item.container=self.destinationInventory;return true
end
function ISInventoryTransferAction:playSourceContainerCloseSound()end
function ISInventoryTransferAction:playDestContainerCloseSound()end
function ISInventoryTransferAction:stopLoopingSound()end

local sequence=0
local function body(id,owner,token)
    local b={data={SAOPersonId=id,SAOExternalOwner=owner,SAOExternalToken=token},inventory={},native={}}
    function b:getModData()return self.data end
    function b:getInventory()return self.inventory end
    function b:getX()return 0 end
    function b:getY()return 0 end
    function b:getZ()return 0 end
    function b:isFarming()return false end
    function b:setIsFarming(value)self.farming=value end
    function b:getCharacterActions()
        local value=self.native
        return {contains=function(_,a)return value[a]==true end}
    end
    bodies[id]=b;people[id]={id=id,bodyOwner=owner,bodyOwnerToken=token};return b
end
local function item(b)
    sequence=sequence+1
    local i={id=sequence,container=b.inventory}
    function i:getID()return self.id end
    function i:getFullType()return "Base.Apple" end
    function i:getContainer()return self.container end
    function i:setJobDelta(value)self.delta=value end
    return i
end
local function start()
    sequence=sequence+1
    local id="actor-"..sequence
    local a,b=body(id),body(id.."-recipient")
    local i=item(a)
    local rec=SAO.Handover.begin(id,a,id.."-recipient",b,i,"food",{effect={trust={{from=id.."-recipient",to=id,delta=1}}}})
    assert(rec,"fixture receipt")
    return rec,a,b,i,SAO.Handover._runtime[rec.id].action
end
local function successor(a)
    local next=ISInventoryTransferAction:new(a,item(a),a.inventory,{})
    ISTimedActionQueue.add(next);return next
end
local function exitNative(a,action)
    action:stop()
    a.native[action.action]=nil
end

function runHandoverCancelCases()
    local checks={}
    local function check(name,value)
        if not value then error("HANDOVER_CANCEL:"..name)end
        checks[#checks+1]=name
    end
    local H=SAO.Handover
    local rec,a,b,i,action=start()
    local next=successor(a)
    local ok,reason=H.cancelAttempt(rec.id,rec.actorId,a,"threat-moved")
    check("current_native_owner_pending",not ok and reason=="pending" and action.action.forced and rec.status=="pending")
    check("cancel_no_transfer_effect",i.container==a.inventory and effects==0 and nativeTransfers==0)
    check("unrelated_queue_preserved",ISTimedActionQueue.hasAction(next) and next.begins==nil)
    H.cancelAttempt(rec.id,rec.actorId,a,"threat-moved")
    check("stop_request_once",stopped==1)
    action:transferItem(i)
    check("cancelled_late_transfer_blocked",nativeTransfers==0 and i.container==a.inventory)
    exitNative(a,action)
    check("successor_started_once",ISTimedActionQueue.hasAction(next) and next.begins==1)
    check("exact_owner_handback",H.cancelAttempt(rec.id,rec.actorId,a,"threat-moved")==true and rec.status=="interrupted")
    action:stop();action:perform();action:transferItem(i)
    check("late_callbacks_leave_successor",next.begins==1 and ISTimedActionQueue.hasAction(next) and nativeTransfers==0 and effects==0)

    rec,a,b,i,action=start();local original=a
    local replacement=body(rec.actorId)
    ok=H.cancelAttempt(rec.id,rec.actorId,replacement,"new-body")
    check("replacement_body_cannot_cancel",not ok and not action.action.forced)
    ok=H.cancelAttempt(rec.id,rec.actorId,original,"old-body")
    check("old_body_not_current",not ok and not action.action.forced)
    action:transferItem(i);action:stop()
    check("replacement_blocks_old_callbacks",i.container==original.inventory and effects==0 and rec.status=="pending")

    rec,a,b,i,action=start()
    local rebound=ISInventoryTransferAction:new(a,i,a.inventory,b.inventory)
    rebound.saoHandoverId=rec.id
    H._runtime[rec.id].action=rebound
    action:transferItem(i);action:stop()
    check("replaced_action_late_callback_blocked",rec.status=="pending" and i.container==a.inventory and effects==0)

    rec,a,b,i,action=start();a.data.SAOExternalToken="successor";people[rec.actorId].bodyOwnerToken="successor"
    ok=H.cancelAttempt(rec.id,rec.actorId,a,"new-token")
    check("stale_attempt_token_refused",not ok and not action.action.forced)
    action:transferItem(i);action:stop()
    check("stale_token_callbacks_blocked",i.container==a.inventory and rec.status=="pending")
    a.data.SAOExternalToken=nil;people[rec.actorId].bodyOwnerToken=nil
    ok,reason=H.cancelAttempt(rec.id,"somebody-else",a,"wrong-actor")
    check("wrong_receipt_actor_refused",not ok and reason=="receipt-owner-mismatch" and not action.action.forced)

    rec,a,b,i,action=start()
    local observedEffects=effects
    people[rec.actorId].bodyOwnerToken="new-record-generation"
    action:transferItem(i);action:stop()
    check("record_token_only_callbacks_blocked",i.container==a.inventory and effects==observedEffects
        and rec.status=="pending" and ISTimedActionQueue.hasAction(action))
    ok,reason=H.cancelAttempt(rec.id,rec.actorId,a,"record-generation-changed")
    check("record_token_only_cancel_refused",not ok and reason=="body-owner-mismatch"
        and not action.action.forced)

    rec,a,b,i,action=start()
    people[rec.recipientId].bodyOwnerToken="new-recipient-generation"
    action:transferItem(i)
    check("recipient_record_generation_revalidated",i.container==a.inventory
        and rec.status=="interrupted")

    rec,a,b,i,action=start();next=successor(a)
    i.container=b.inventory -- transfer occurred before this cancellation's callback/reconcile.
    local before=effects
    ok,reason=H.cancelAttempt(rec.id,rec.actorId,a,"already-transferred")
    check("physical_completion_preserved",not ok and reason=="pending" and rec.status=="completed" and effects==before+1)
    exitNative(a,action)
    check("completed_native_handback",H.cancelAttempt(rec.id,rec.actorId,a)==true and rec.status=="completed" and next.begins==1)
    H.reconcile(true);H.cancelAttempt(rec.id,rec.actorId,a)
    check("completed_effect_once",effects==before+1)

    rec,a,b,i,action=start();action:transferItem(i)
    check("callback_completion_setup",rec.status=="completed")
    ok,reason=H.cancelAttempt(rec.id,rec.actorId,a,"completed-still-native")
    check("terminal_receipt_does_not_release_native",not ok and reason=="pending" and action.action.forced)
    exitNative(a,action);check("completed_receipt_retired",H.cancelAttempt(rec.id,rec.actorId,a)==true)

    rec,a,b,i,action=start()
    local unrelated=successor(a)
    local queuedItem=item(a)
    local queued=H.begin(rec.actorId,a,rec.recipientId,b,queuedItem,"food")
    local queuedAction=H._runtime[queued.id].action
    check("queued_exact_removal",H.cancelAttempt(queued.id,rec.actorId,a)==true
        and not ISTimedActionQueue.hasAction(queuedAction) and ISTimedActionQueue.hasAction(action)
        and ISTimedActionQueue.hasAction(unrelated) and not action.action.forced)
    queuedAction:perform();queuedAction:transferItem(queuedItem)
    check("removed_queued_callback_blocked",queuedItem.container==a.inventory and unrelated.begins==nil)

    rec,a,b,i,action=start()
    local held=action.action
    ISTimedActionQueue.queues[a]:removeFromQueue(action)
    H.reconcile(true)
    ok,reason=H.cancelAttempt(rec.id,rec.actorId,a,"native-still-present")
    check("native_stack_survives_lua_removal",not ok and reason=="pending" and a.native[held])

    -- Correctly mapped foreign bodies retain the same queue/handback contract.
    a=body("foreign-giver","fixture-native-owner","foreign-generation");a.shell=false
    b=body("foreign-recipient","fixture-recipient-owner","recipient-generation");b.shell=false
    i=item(a)
    rec=H.begin("foreign-giver",a,"foreign-recipient",b,i,"food")
    check("canonical_foreign_body_admitted",rec~=nil)
    action=H._runtime[rec.id].action
    ok,reason=H.cancelAttempt(rec.id,rec.actorId,a,"foreign-purpose-ended")
    check("canonical_foreign_handback_waits",not ok and reason=="pending" and action.action.forced)
    exitNative(a,action)
    check("canonical_foreign_handback_observed",H.cancelAttempt(rec.id,rec.actorId,a)==true
        and rec.status=="interrupted" and i.container==a.inventory)
    people["foreign-giver"].bodyOwner="another-owner"
    check("foreign_owner_mismatch_refused",H.begin("foreign-giver",a,"foreign-recipient",b,item(a),"food")==nil)

    -- Isolate a new fixture world at exact production capacity. The only
    -- terminal receipt still owns its native action and cannot be evicted.
    stores.SurvivorAwareness_Handovers={};H.rebindWorld()
    rec,a,b,i,action=start();action:transferItem(i)
    local storage=stores.SurvivorAwareness_Handovers
    for n=1,511 do
        storage.records["capacity-pending-"..n]={id="capacity-pending-"..n,status="pending",createdAt=100}
    end
    local newcomer,recipient=body("capacity-new"),body("capacity-recipient")
    local offered=item(newcomer)
    local admitted,why=H.begin("capacity-new",newcomer,"capacity-recipient",recipient,offered,"food")
    check("trim_preserves_native_held_terminal",admitted==nil and why=="handover-capacity"
        and H.result(rec.id)==rec and rec.status=="completed" and a.native[action.action]
        and ISTimedActionQueue.hasAction(action))
    ok,reason=H.cancelAttempt(rec.id,rec.actorId,a,"capacity-handback")
    check("trim_preserved_attempt_can_request_handback",not ok and reason=="pending" and action.action.forced)
    exitNative(a,action)
    check("trim_preserved_attempt_retires_exactly",H.cancelAttempt(rec.id,rec.actorId,a)==true)
    admitted=H.begin("capacity-new",newcomer,"capacity-recipient",recipient,offered,"food")
    check("trim_reclaims_only_after_handback",admitted~=nil and H.result(rec.id)==nil)
    return "PASS handover cancellation checks="..#checks
end
