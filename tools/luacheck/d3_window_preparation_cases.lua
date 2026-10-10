-- Actual installed transfer/queue and repair action over controlled body/map/inventory receivers.
ISInventoryPage={}
CharacterTrait={DEXTROUS='Dextrous',ALL_THUMBS='AllThumbs'}
function isClient() return false end
function isServer() return false end
function getTimestampMs() return 10000 end
function getCore() return {getGameMode=function() return 'Sandbox' end} end
local originalTimed=LuaTimedActionNew.new
LuaTimedActionNew.new=function(action,body)
    local native=originalTimed(action,body)
    native.finished=function() return native.nativeFinished==true end
    native.isForceComplete=function() return false end
    native.stopTimedActionAnim=function() end
    native.setLoopedAction=function() end
    return native
end
local function inventory(inv,root)
    inv.root=root or inv
    function inv:getOutermostContainer() return self.root end
    function inv:getFirstTypeRecurse(t) return self:getFirstType(t) or self.nested and self.nested:getFirstType(t) end
    function inv:getFirstTypeEval(t,predicate)
        for _,item in ipairs(self.items) do if item:getFullType()==t and predicate(item) then return item end end
    end
    function inv:getFirstTypeEvalRecurse(t,predicate)
        return self:getFirstTypeEval(t,predicate) or self.nested and self.nested:getFirstTypeEvalRecurse(t,predicate)
    end
    function inv:getType() return 'inventory' end
    function inv:getParent() return nil end
    function inv:isExistYet() return true end
    function inv:hasRoomFor() return true end
    function inv:isRemoveItemAllowed() return true end
    function inv:isItemAllowed() return true end
    function inv:isInside() return false end
    function inv:isInCharacterInventory(body) return self:getOutermostContainer()==body:getInventory() end
    function inv:isVehicleSeat() return false end
    function inv:getCapacityWeight() return 1 end
    function inv:getMaxWeight() return 50 end
    function inv:setDrawDirty(v) self.dirty=v end
    function inv:setHasBeenLooted(v) self.looted=v end
    function inv:DoRemoveItem(i)
        self.nativeRemovals=(self.nativeRemovals or 0)+1
        if not self.keepNativeRemoval then self:Remove(i) end
    end
    function inv:AddItem(i)
        self.nativeAdds=(self.nativeAdds or 0)+1
        if self.nativeAddThrows then error('controlled native destination failure') end
        if not self.refuseNativeAdd then self.items[#self.items+1]=i;i.container=self end
        return i
    end
    return inv
end
local function fixture(id)
    local f=__windowFixture('pane-prep-'..id)
    inventory(f.inventory)
    local source={items={f.pane}}
    function source:getFirstType(t)
        for _,i in ipairs(self.items) do if i:getFullType()==t then return i end end
    end
    function source:contains(i) for _,x in ipairs(self.items) do if x==i then return true end end;return false end
    function source:Remove(i)
        for n,x in ipairs(self.items) do if x==i then table.remove(self.items,n);i.container=nil;return end end
    end
    inventory(source,f.inventory)
    f.source=source;f.inventory.items={};f.inventory.nested=source;f.pane.container=source
    function f.pane:getType() return 'LargeGlassPane' end
    function f.pane:getName() return 'Large Glass Pane' end
    function f.pane:getIsCraftingConsumed() return self.consumed==true end
    function f.pane:setJobDelta(v) self.jobDelta=v end
    function f.pane:isFavorite() return false end
    function f.pane:getActualWeight() return 2 end
    function f.body:hasTrait() return false end
    function f.body:isWearingAwkwardGloves() return false end
    function f.body:getEmitter() return {isPlaying=function() return false end,playSound=function() end} end
    return f
end
local function configureTransfer(a)
    -- Floor selection is irrelevant for a bag -> owned root transfer; hardware sound stays controlled.
    a.getNotFullFloorSquare=function() return nil end
    a.playTransferCompleteSound=function() end
    a.playSourceContainerCloseSound=function() end
    a.playDestContainerCloseSound=function() end
    a.stopLoopingSound=function() end
end
local function finishTransfer(a)
    configureTransfer(a)
    a.action.nativeFinished=true
    return a:perform()
end
local function noRepair(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    return f.window.smashed and not f.window.synced and f.rec.windowRepairWork.status=='interrupted'
        and (q.current==nil or q.current.Type~='RepairableWindowsAddWindowAction')
end
function __runWindowPreparationCases()
    local W,P,A=SAO.WindowRepair,SAO.ProceduralPlanning,RepairableWindowsAddWindowAction
    local check=__windowCheck
    W.install()
    local ctor=A.new
    A.new=function(self,character,window)
        local a=ctor(self,character,window);character.lastRepair=a;return a
    end
    local f=fixture('completed')
    local a=__windowAdmitted(f)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    local p=f.rec.proceduralPlanning.purposes[f.rec.windowRepairWork.purposeId]
    check('prep_native_exact_child',a.Type=='ISInventoryTransferAction' and a.item==f.pane
        and a.srcContainer==f.source and a.destContainer==f.inventory and #q.queue==1)
    check('prep_admission_no_effect',f.source:contains(f.pane) and not f.inventory:contains(f.pane)
        and not f.source.nativeRemovals and not f.inventory.nativeAdds and f.window.smashed
        and p.cursor==1 and W.outcome(f.id,1)==nil)
    check('prep_native_validity',a:isValidStart()==true and a:isValid()==true and W.active(f.id,f.body)==true)
    check('prep_final_repair_not_admitted_early',f.body.lastRepair:isValidStart()==false
        and f.body.lastRepair:isValid()==false and f.window.smashed)
    check('prep_child_complete_has_no_effect',a:complete()==false and f.source:contains(f.pane) and f.window.smashed)
    local work=f.rec.windowRepairWork
    __hours=101
    check('prep_actual_native_transfer',finishTransfer(a)==true and not f.source:contains(f.pane)
        and f.inventory:contains(f.pane) and f.pane:getContainer()==f.inventory
        and f.source.nativeRemovals==1 and f.inventory.nativeAdds==1)
    local final=q.current
    check('prep_measured_root_then_exact_repair',final==f.body.lastRepair and #q.queue==1 and final:isValidStart()==true
        and f.rec.windowRepairWork==work and p.admission.correlationId==work.id and p.cursor==1 and f.window.smashed)
    check('prep_completed_child_tombstone',a:perform()==false and a:complete()==false and a:stop()==false
        and a:isValid()==false and a._SAOWindowRepairPreparation==false)
    __hours=102
    local completed=final:complete()
    final:perform()
    local row=W.outcome(f.id,1)
    check('prep_native_repair_one_result',completed==true and row and row.status=='completed'
        and row.paneConsumed and not f.window.smashed and f.inventory.sent==1 and f.window.synced==1
        and row.workId==work.id and row.itemId==tostring(f.pane:getID()) and W.runtimeCount()==0)
    check('prep_planner_credit_after_physical_completion',p.status=='completed' and p.cursor==2
        and row.planningAcknowledged and P.techniqueProfile(f.id).practice[row.entryKey].completed==1)
    __records[f.id]=__nativeRoundtrip(f.rec)
    check('prep_native_saved_result_once',W.outcome(f.id,1).status=='completed'
        and P.consumeWindowRepairOutcome(f.id,1)==true and __records[f.id].windowRepair.nextResult==1)

    local shadow=fixture('reserved-shadow')
    local reserved={}
    for key,value in pairs(shadow.pane) do reserved[key]=value end
    reserved.id=714;reserved.consumed=true
    table.insert(shadow.source.items,1,reserved)
    local shadowOffer=W.offer(shadow.id,shadow.body)
    local shadowBegun=shadowOffer and W.begin(shadow.id,shadow.body,shadowOffer)
    local shadowQueue=ISTimedActionQueue.getTimedActionQueue(shadow.body)
    local transfer=shadowQueue.current
    check('prep_reserved_nested_shadow_is_skipped',shadowBegun==true and transfer.item==shadow.pane
        and shadow.source:contains(reserved) and not shadow.source.nativeRemovals)
    local shadowCompleted=false
    if shadowBegun then
        finishTransfer(transfer)
        shadowCompleted=shadowQueue.current:complete()==true
        shadowQueue.current:perform()
    end
    check('prep_reserved_shadow_exact_native_completion',shadowCompleted and shadow.source:contains(reserved)
        and not shadow.source:contains(shadow.pane) and not shadow.window.smashed
        and W.outcome(shadow.id,1).itemId==tostring(shadow.pane:getID()))
    W.interrupt(shadow.id,shadow.body,'fixture-retire')

    local reservedOnly=fixture('reserved-only');reservedOnly.pane.consumed=true
    local reservedOffer=W.offer(reservedOnly.id,reservedOnly.body)
    check('prep_reserved_only_refuses_without_effect',reservedOffer
        and W.begin(reservedOnly.id,reservedOnly.body,reservedOffer)==false
        and reservedOnly.source:contains(reservedOnly.pane) and not reservedOnly.source.nativeRemovals
        and reservedOnly.window.smashed and reservedOnly.rec.windowRepairWork==nil)

    local lateReserved=fixture('late-reserved');__windowAdmitted(lateReserved)
    lateReserved.pane.consumed=true
    check('prep_bound_pane_reservation_drift_refuses',W.active(lateReserved.id,lateReserved.body)==false
        and lateReserved.source:contains(lateReserved.pane) and not lateReserved.source.nativeRemovals
        and lateReserved.window.smashed)
    W.interrupt(lateReserved.id,lateReserved.body,'fixture-retire')

    local premature=fixture('early-final');__windowAdmitted(premature)
    check('prep_unqueued_final_complete_refuses',premature.body.lastRepair:complete()==false
        and premature.window.smashed and premature.source:contains(premature.pane)
        and not premature.inventory.nativeAdds)
    W.interrupt(premature.id,premature.body,'fixture-retire')

    local early=fixture('early');local e=__windowAdmitted(early)
    configureTransfer(e)
    check('prep_perform_before_native_end_refuses',e:perform()==false and noRepair(early)
        and early.source:contains(early.pane) and not early.source.nativeRemovals and W.runtimeCount()==0)
    W.interrupt(early.id,early.body,'fixture-retire')

    local outer=fixture('outer');local o=__windowAdmitted(outer)
    outer.source.root={}
    check('prep_changed_outer_owner_refuses',finishTransfer(o)==false and noRepair(outer)
        and outer.source:contains(outer.pane) and not outer.inventory.nativeAdds and W.runtimeCount()==0)

    local shadow=fixture('shadow');local s=__windowAdmitted(shadow)
    s.item={getID=function() return shadow.pane:getID() end}
    check('prep_same_id_item_shadow_refuses',finishTransfer(s)==false and noRepair(shadow)
        and shadow.source:contains(shadow.pane) and not shadow.inventory.nativeAdds and W.runtimeCount()==0)

    local payload=fixture('payload');local pl=__windowAdmitted(payload)
    pl.queueList[1].items[2]=payload.pane
    check('prep_extra_native_payload_refuses',finishTransfer(pl)==false and noRepair(payload)
        and not payload.source.nativeRemovals and W.runtimeCount()==0)

    local target=fixture('destination');local t=__windowAdmitted(target)
    t.destContainer=target.source
    check('prep_destination_shadow_refuses',finishTransfer(t)==false and noRepair(target)
        and not target.source.nativeRemovals and W.runtimeCount()==0)

    local purpose=fixture('purpose');local pa=__windowAdmitted(purpose)
    local pp=purpose.rec.proceduralPlanning.purposes[purpose.rec.windowRepairWork.purposeId]
    pp.admission.correlationId='different-work'
    check('prep_changed_purpose_refuses',finishTransfer(pa)==false and noRepair(purpose)
        and not purpose.source.nativeRemovals and W.runtimeCount()==0)

    local rootMissing=fixture('no-root');local rm=__windowAdmitted(rootMissing)
    rootMissing.inventory.refuseNativeAdd=true
    check('prep_missing_root_poststate_refuses',finishTransfer(rm)==false and noRepair(rootMissing)
        and not rootMissing.inventory:contains(rootMissing.pane) and W.runtimeCount()==0)

    local sourceRemains=fixture('source-remains');local sr=__windowAdmitted(sourceRemains)
    sourceRemains.source.keepNativeRemoval=true
    check('prep_source_absence_measured',finishTransfer(sr)==false and noRepair(sourceRemains)
        and sourceRemains.inventory:contains(sourceRemains.pane) and sourceRemains.source:contains(sourceRemains.pane)
        and W.runtimeCount()==0)

    local fault=fixture('fault');local ft=__windowAdmitted(fault)
    fault.inventory.nativeAddThrows=true;fault.body.holdCancellation=true
    check('prep_native_fault_retains_ack',finishTransfer(ft)==false and noRepair(fault)
        and W.runtimeCount()==1 and fault.body.stopRequests>=1)
    ft:stop()
    check('prep_native_fault_late_ack_retires',W.runtimeCount()==0 and ft:isValid()==false)

    for _,reason in ipairs({'death','transfer','world'}) do
        local pending=fixture(reason);local action=__windowAdmitted(pending)
        local oldQueue=ISTimedActionQueue.getTimedActionQueue(pending.body)
        pending.body.holdCancellation=true
        if reason=='death' then pending.body.dead=true;pending.rec.dead=true;W.active(pending.id,pending.body)
        elseif reason=='transfer' then pending.rec.zaoTransferPending={};W.active(pending.id,pending.body)
        else __world.name='changed-world';W.reset('controlled-world-reset') end
        oldQueue:removeFromQueue(action);oldQueue.current=nil
        __fireWindowRetry()
        check('prep_'..reason..'_queue_absence_is_not_ack',W.runtimeCount()==1 and noRepair(pending)
            and action._SAOWindowRepairPreparation~=false and pending.source:contains(pending.pane))
        action:stop()
        check('prep_'..reason..'_late_ack_retires',W.runtimeCount()==0 and action._SAOWindowRepairPreparation==false
            and pending.source:contains(pending.pane))
    end

    local replaced=fixture('queue');local rq=__windowAdmitted(replaced)
    local oldQueue=ISTimedActionQueue.getTimedActionQueue(replaced.body)
    local successor={Type='UnrelatedSuccessor',character=replaced.body}
    local successorQueue={current=successor,queue={successor},indexOf=function() return -1 end}
    ISTimedActionQueue.queues[replaced.body]=successorQueue
    replaced.body.farming=true;replaced.body.holdCancellation=true
    check('prep_replaced_queue_refuses_native_effect',finishTransfer(rq)==false and W.runtimeCount()==1
        and replaced.source:contains(replaced.pane) and not replaced.inventory.nativeAdds)
    rq:stop()
    check('prep_late_ack_preserves_successor',W.runtimeCount()==0 and #oldQueue.queue==0
        and successorQueue.current==successor and #successorQueue.queue==1 and replaced.body.farming==true)

    local finalPurpose=fixture('final-purpose');local fp=__windowAdmitted(finalPurpose)
    finishTransfer(fp)
    local repair=ISTimedActionQueue.getTimedActionQueue(finalPurpose.body).current
    local purposeRow=finalPurpose.rec.proceduralPlanning.purposes[finalPurpose.rec.windowRepairWork.purposeId]
    purposeRow.admission.correlationId='replacement'
    check('prep_final_exact_purpose_refuses',repair:complete()==false and finalPurpose.window.smashed
        and finalPurpose.inventory:contains(finalPurpose.pane))
    W.interrupt(finalPurpose.id,finalPurpose.body,'fixture-retire')
    check('prep_all_runtime_retires',W.runtimeCount()==0)
    A.new=ctor
    __windowResults=table.concat(__checks,'\n')
end

-- Persist genuinely admitted work before retiring its old native owner. The
-- restored snapshot still names that pending admission, without Lua runtime.
local function savedPending(id, legacy)
    local W=SAO.WindowRepair
    local f=fixture('recovery-'..id)
    f.world=getWorld()
    local a=__windowAdmitted(f)
    local p=f.rec.proceduralPlanning.purposes[f.rec.windowRepairWork.purposeId]
    p.constructionDestination={key=f.rec.windowRepairWork.entryKey,x=0,y=0,z=0}
    local saved=__nativeRoundtrip(f.rec)
    W.interrupt(f.id,f.body,'controlled-old-owner-retirement')
    if W.runtimeCount()~=0 then error('old native owner did not acknowledge '..id) end
    if legacy then
        local w=saved.windowRepairWork
        saved.windowRepairWork={id=w.id,purposeId=w.purposeId,entryKey=w.entryKey,
            status=w.status,startedAt=w.startedAt,itemId=w.itemId}
        saved=__nativeRoundtrip(saved)
    end
    __records[f.id]=saved;f.rec=saved
    return f
end
function __setupWindowRecoveryCases()
    __windowRecoveryFixtures={}
    for _,name in ipairs({'pending','active','native-pending','legacy','legacy-interrupted','correlation','clock','ledger','anchors'}) do
        __windowRecoveryFixtures[name]=savedPending(name,name=='legacy' or name=='legacy-interrupted')
    end
    local W,P=SAO.WindowRepair,SAO.ProceduralPlanning
    local terminal=fixture('recovery-terminal');terminal.world=getWorld()
    local transfer=__windowAdmitted(terminal);finishTransfer(transfer)
    local action=ISTimedActionQueue.getTimedActionQueue(terminal.body).current
    local consumer=P.consumeWindowRepairOutcome
    P.consumeWindowRepairOutcome=function() return false end
    if action:complete()~=true then error('canonical native terminal effect failed') end
    action:perform()
    local saved=__nativeRoundtrip(terminal.rec)
    P.consumeWindowRepairOutcome=consumer
    __records[terminal.id]=saved;terminal.rec=saved
    __windowRecoveryFixtures.terminal=terminal
    if W.runtimeCount()~=0 then error('old terminal runtime retained') end
    -- The runner reloads the actual installed optional class and production
    -- owner into this fresh slot before executing the recovery assertions.
    SAO.WindowRepair={}
end
local function activateSaved(f) __world=f.world end
function __runWindowRecoveryCases()
    local W,P,check=SAO.WindowRepair,SAO.ProceduralPlanning,__windowCheck
    local cases=__windowRecoveryFixtures
    local f=cases.pending;activateSaved(f)
    local work=f.rec.windowRepairWork
    local p=f.rec.proceduralPlanning.purposes[work.purposeId]
    local destination=p.constructionDestination
    check('recovery_fresh_owner_has_no_runtime',W.runtimeCount()==0 and work.status=='repairing'
        and p.admission.correlationId==work.id and p.cursor==1)
    check('recovery_saved_pending_reconciles',W.reconcileSaved(f.id,f.body)==true and p.admission==nil
        and work.status=='interrupted' and work.resultSequence==1 and f.rec.windowRepair.nextResult==1)
    local result=W.outcome(f.id,1)
    check('recovery_no_physical_or_completion_claims',result and result.recoveryOnly==true and result.status=='interrupted'
        and result.nativeObservability=='runtime-unavailable' and result.paneConsumed==nil
        and result.nativeAttempted==nil and result.smashedAfter==nil and result.glassRemovedAfter==nil
        and f.window.smashed and f.source:contains(f.pane) and not f.source.nativeRemovals and not f.inventory.nativeAdds
        and p.cursor==1 and P.techniqueProfile(f.id).practice[work.entryKey].completed==0)
    check('recovery_retains_exact_purpose_destination',p.id==work.purposeId and p.status=='interrupted'
        and p.constructionDestination==destination and destination.key==work.entryKey and p.lastAdmission.correlationId==work.id)
    __records[f.id]=__nativeRoundtrip(f.rec);f.rec=__records[f.id]
    check('recovery_serialized_result_replays_once',W.reconcileSaved(f.id,f.body)==true
        and P.consumeWindowRepairOutcome(f.id,1)==true and f.rec.windowRepair.nextResult==1
        and P.techniqueProfile(f.id).practice[work.entryKey].failed==1)
    f.rec.windowRepair.outcomes['1'].nativeAttempted=false
    check('recovery_effect_facts_refuse_authentication',W.outcome(f.id,1)==nil)
    f.rec.windowRepair.outcomes['1'].nativeAttempted=nil
    f.rec.windowRepair.outcomes['1'].status='completed'
    check('recovery_completed_variant_refuses_authentication',W.outcome(f.id,1)==nil)
    f.rec.windowRepair.outcomes['1'].status='interrupted'

    local active=cases.active;activateSaved(active)
    local activeWork=active.rec.windowRepairWork
    check('recovery_active_no_runtime_uses_owner_result',W.active(active.id,active.body)==false
        and active.rec.windowRepair.nextResult==1 and activeWork.status=='interrupted'
        and active.rec.proceduralPlanning.purposes[activeWork.purposeId].admission==nil
        and W.outcome(active.id,1).recoveryOnly==true)

    local pending=cases['native-pending'];activateSaved(pending)
    local bridgePending=SAOJavaBridge.hasPendingActions
    SAOJavaBridge.hasPendingActions=function(self,body) return body.nativePending==true or bridgePending(self,body) end
    pending.body.nativePending=true
    local pendingWork=pending.rec.windowRepairWork
    check('recovery_missing_lua_queue_does_not_ack_native',W.reconcileSaved(pending.id,pending.body)==false
        and pendingWork.status=='repairing' and pending.rec.windowRepair.nextResult==0
        and pending.rec.proceduralPlanning.purposes[pendingWork.purposeId].admission.correlationId==pendingWork.id)
    pending.body.nativePending=false
    check('recovery_native_queue_ack_allows_retirement',W.reconcileSaved(pending.id,pending.body)==true
        and pending.rec.windowRepair.nextResult==1 and pending.source:contains(pending.pane))
    SAOJavaBridge.hasPendingActions=bridgePending

    local legacy=cases.legacy;activateSaved(legacy)
    local legacyWork=legacy.rec.windowRepairWork
    check('recovery_legacy_six_scalar_work',legacyWork.world==nil and legacyWork.stepId==nil
        and W.reconcileSaved(legacy.id,legacy.body)==true)
    local oldResult=W.outcome(legacy.id,1)
    check('recovery_legacy_has_no_invented_native_anchors',oldResult and oldResult.recoveryOnly==true
        and oldResult.world==nil and oldResult.x==nil and oldResult.north==nil and oldResult.paneConsumed==nil
        and legacy.source:contains(legacy.pane) and legacy.rec.proceduralPlanning.purposes[legacyWork.purposeId].admission==nil)
    local legacyInterrupted=cases['legacy-interrupted'];activateSaved(legacyInterrupted)
    local oldWork=legacyInterrupted.rec.windowRepairWork
    oldWork.status='interrupted';oldWork.reason='window-runtime-unavailable'
    P.interrupt(legacyInterrupted.id,oldWork.purposeId,'window-runtime-unavailable',__hours)
    check('recovery_prior_interruption_releases_exact_pin',W.reconcileSaved(legacyInterrupted.id,legacyInterrupted.body)==true
        and legacyInterrupted.rec.proceduralPlanning.purposes[oldWork.purposeId].admission==nil
        and legacyInterrupted.rec.windowRepair.nextResult==1)

    local correlation=cases.correlation;activateSaved(correlation)
    local correlationWork=correlation.rec.windowRepairWork
    local correlationPurpose=correlation.rec.proceduralPlanning.purposes[correlationWork.purposeId]
    correlationPurpose.admission.correlationId='different-native-work'
    check('recovery_changed_correlation_refuses_without_mutation',W.reconcileSaved(correlation.id,correlation.body)==false
        and correlation.rec.windowRepair.nextResult==0 and correlationWork.status=='repairing'
        and correlationPurpose.admission.correlationId=='different-native-work')
    local clock=cases.clock;activateSaved(clock)
    local current=__hours;__hours=clock.rec.windowRepairWork.startedAt-1
    check('recovery_clock_rewind_refuses_without_mutation',W.reconcileSaved(clock.id,clock.body)==false
        and clock.rec.windowRepair.nextResult==0 and clock.rec.windowRepairWork.status=='repairing')
    __hours=current
    local ledger=cases.ledger;activateSaved(ledger)
    ledger.rec.windowRepair.nextWork=0
    check('recovery_malformed_work_sequence_refuses',W.reconcileSaved(ledger.id,ledger.body)==false
        and ledger.rec.windowRepair.nextResult==0 and ledger.rec.windowRepairWork.status=='repairing')
    local anchors=cases.anchors;activateSaved(anchors)
    anchors.rec.windowRepairWork.x=999
    check('recovery_malformed_native_anchor_refuses',W.reconcileSaved(anchors.id,anchors.body)==false
        and anchors.rec.windowRepair.nextResult==0 and anchors.rec.windowRepairWork.status=='repairing')

    local terminal=cases.terminal;activateSaved(terminal)
    local terminalWork=terminal.rec.windowRepairWork
    local terminalPurpose=terminal.rec.proceduralPlanning.purposes[terminalWork.purposeId]
    check('recovery_authentic_saved_terminal_retries',terminal.rec.windowRepair.outcomes['1'].planningAcknowledged==nil
        and W.reconcileSaved(terminal.id,terminal.body)==true and terminalPurpose.admission==nil
        and terminalPurpose.status=='completed' and terminal.rec.windowRepair.nextResult==1
        and terminal.inventory.sent==1 and terminal.window.synced==1 and not terminal.window.smashed)
    check('recovery_terminal_credit_is_native_once',W.reconcileSaved(terminal.id,terminal.body)==true
        and P.techniqueProfile(terminal.id).practice[terminalWork.entryKey].completed==1
        and terminal.inventory.sent==1 and terminal.window.synced==1)

    local live=fixture('recovery-live');local action=__windowAdmitted(live)
    live.body.holdCancellation=true
    check('recovery_live_owner_waits_for_native_ack',W.reconcileSaved(live.id,live.body)==false
        and W.runtimeCount()==1 and action._SAOWindowRepairPreparation~=false and live.source:contains(live.pane))
    local q=ISTimedActionQueue.getTimedActionQueue(live.body)
    q:removeFromQueue(action);q.current=nil
    check('recovery_live_queue_absence_preserves_ack_owner',W.reconcileSaved(live.id,live.body)==false
        and W.runtimeCount()==1 and live.rec.windowRepair.nextResult==1)
    action:stop()
    check('recovery_live_ack_retires_once',W.reconcileSaved(live.id,live.body)==true and W.runtimeCount()==0
        and live.rec.windowRepair.nextResult==1 and live.source:contains(live.pane))
    __windowResults=table.concat(__checks,'\n')
end
