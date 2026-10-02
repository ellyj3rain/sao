-- Installed VM remains live; retire only test registry/geometry roots, never
-- the engine action.character/window fields. Java WeakReferences inspect GC.
function __setupWindowDisposal()
    local W,A=SAO.WindowRepair,RepairableWindowsAddWindowAction
    local fixture,admitted,check=__windowFixture,__windowAdmitted,__windowCheck
    W.reset('disposal-controls');W.retryCancellations()
    __retentionKeptActions={}
    local function player(id)
        local f=fixture(id);f.body.md.SAOPersonId=nil
        return f
    end
    local function dropRegistry(f)
        SAO.Body.active[f.id]=nil
        ISTimedActionQueue.queues[f.body]=nil
    end
    local function unrelated(body)
        -- The installed queue may restart/cancel this real base action under
        -- an omitted guard; those effects must be observations, not stub errors.
        local action=ISBaseTimedAction:new(body)
        function action:isValid() return true end
        return action
    end
    local discarded=player('disposal-constructor')
    local constructor=A:new(discarded.body,discarded.window)
    __retentionTrack('constructor-action',constructor)
    __retentionTrack('constructor-binding',constructor._SAOWindowRepairBinding)
    __retentionTrack('constructor-body',discarded.body)
    dropRegistry(discarded)

    for _,mode in ipairs({'completed','stopped','failed','force-cancelled'}) do
        local f=player('disposal-player-'..mode);local action=A:new(f.body,f.window)
        __retentionTrack('player-'..mode..'-binding',action._SAOWindowRepairBinding)
        check('disposal_player_'..mode:gsub('-','_')..'_first_pin',action:isValid()==true)
        if mode=='completed' then action:complete();action:perform()
        elseif mode=='stopped' then action:stop()
        elseif mode=='force-cancelled' then action:forceCancel()
        else f.inventory:Remove(f.pane);action:complete();action:perform() end
        check('disposal_player_'..mode:gsub('-','_')..'_terminal_tombstone',action._SAOWindowRepairBinding==false
            and action.character==f.body and action.window==f.window)
        f.window.smashed=true;f.window.glass=true;f.inventory.items={f.pane};f.pane.container=f.inventory
        check('disposal_player_'..mode:gsub('-','_')..'_cannot_recapture',action:isValid()==false
            and action:complete()==false and f.inventory:contains(f.pane))
        __retentionKeptActions[mode]=action
        dropRegistry(f)
    end
    local net=player('disposal-network');local netAction=A:new(net.body,net.window)
    check('disposal_native_network_argument_names',__nativeActionArgs(netAction)==true)
    check('disposal_private_binding_token_refuses_public_access',netAction._SAOWindowRepairBinding(nil)==nil)
    netAction._SAOWindowRepairBinding=function() return {body=net.body,window=net.window} end
    check('disposal_forged_binding_accessor_refuses',netAction:isValid()==false and netAction:complete()==false
        and net.inventory:contains(net.pane) and net.window.smashed)
    dropRegistry(net)

    local npc=fixture('disposal-npc');local npcAction=admitted(npc)
    __retentionTrack('npc-completed-binding',npcAction._SAOWindowRepairBinding)
    local completed=npcAction:complete();npcAction:perform()
    check('disposal_npc_completed_terminal_tombstone',completed and npcAction._SAOWindowRepairBinding==false
        and npcAction.character==npc.body and npcAction.window==npc.window
        and W.outcome(npc.id,1).status=='completed')
    __retentionKeptActions.npc=npcAction;dropRegistry(npc)

    for _,kind in ipairs({'player','npc'}) do
        local f=kind=='player' and player('disposal-duplicate-'..kind) or fixture('disposal-duplicate-'..kind)
        local action
        if kind=='player' then action=A:new(f.body,f.window);ISTimedActionQueue.add(action)
        else action=admitted(f) end
        local completed=action:complete();action:perform()
        local other=unrelated(f.body)
        local q=ISTimedActionQueue.getTimedActionQueue(f.body)
        q.current=other;q.queue={other};f.body.farming=true
        check('disposal_'..kind..'_duplicate_terminal_callbacks_inert',completed
            and action:perform()==false and action:stop()==false and q.current==other
            and #q.queue==1 and q.queue[1]==other and f.body.farming==true
            and action.character==f.body and action.window==f.window)
        dropRegistry(f)
    end
    local foreign=fixture('disposal-perform-foreign-queue');local foreignAction=admitted(foreign)
    local oldQueue=ISTimedActionQueue.getTimedActionQueue(foreign.body)
    local physical=foreignAction:complete()
    ISTimedActionQueue.queues[foreign.body]=nil
    local newQueue=ISTimedActionQueue.getTimedActionQueue(foreign.body)
    local foreignWork=unrelated(foreign.body);newQueue.current=foreignWork;newQueue.queue={foreignWork}
    check('disposal_perform_refuses_replaced_queue',physical and foreignAction:perform()==false
        and oldQueue.current==foreignAction and newQueue.current==foreignWork
        and #newQueue.queue==1 and newQueue.queue[1]==foreignWork)
    foreignAction:stop();dropRegistry(foreign)

    local pending=fixture('disposal-pending');local pendingAction=admitted(pending)
    __retentionTrack('npc-pending-binding',pendingAction._SAOWindowRepairBinding)
    pending.body.holdCancellation=true
    local pendingCount=W.runtimeCount()
    local originalQueue=ISTimedActionQueue.getTimedActionQueue(pending.body)
    W.forget(pending.id);originalQueue:resetQueue()
    -- Replacement of the engine's Lua lookup must not replace our old queue.
    ISTimedActionQueue.queues[pending.body]=nil
    local replacementQueue=ISTimedActionQueue.getTimedActionQueue(pending.body)
    check('disposal_pending_native_ack_retains_binding',W.runtimeCount()==pendingCount
        and type(pendingAction._SAOWindowRepairBinding)=='function' and originalQueue~=replacementQueue)
    __retentionKeptActions.pending=pendingAction
    __retentionPendingId=pending.id;dropRegistry(pending)

    local offer=fixture('disposal-offer-old')
    local opaque=W.offer(offer.id,offer.body)
    __retentionTrack('offer-abandoned',opaque);__retentionTrack('offer-abandoned-body',offer.body)
    dropRegistry(offer)
    local replaced=fixture('disposal-replaced')
    local prior=W.offer(replaced.id,replaced.body)
    __retentionTrack('offer-replaced',prior);__retentionTrack('offer-replaced-body',replaced.body)
    dropRegistry(replaced)
    local newer=fixture(replaced.id);local latest=W.offer(newer.id,newer.body)
    check('disposal_only_latest_offer_admits',W.offerCount()==2 and W.begin(newer.id,newer.body,prior)==false
        and newer.window.smashed and newer.inventory:contains(newer.pane))
    -- begin consumed/refused that person's latest slot, including native refs.
    dropRegistry(newer)

    local dying=fixture('disposal-offer-death')
    dying.rec.forename,dying.rec.surname,dying.rec.x,dying.rec.y='Control','Actor',0,0
    SAO.Controller.agents[dying.id]=dying.agent
    local doomed=W.offer(dying.id,dying.body)
    __retentionTrack('offer-dead',doomed);__retentionTrack('offer-dead-body',dying.body)
    dying.body.dead=true;__updateAgent(dying.id,dying.agent);dropRegistry(dying)
    check('disposal_death_retires_unconsumed_offer',dying.rec.dead and W.offerCount()==1)
    check('disposal_death_preserves_separate_corpse_owner',SAO.Controller.pendingCorpses[dying.id]
        and SAO.Controller.pendingCorpses[dying.id].body==dying.body)
    -- The controlled corpse owner has finished its separate handoff. Retire
    -- that fixture root, without altering any native action/body/window field.
    SAO.Controller.pendingCorpses[dying.id]=nil
    fixture('disposal-surviving-world')
end

function __observeWindowDisposal()
    local W,check=SAO.WindowRepair,__windowCheck
    __retentionCollect()
    check('disposal_ctor_action_collected',not __retentionAlive('constructor-action'))
    check('disposal_ctor_binding_and_body_collected',not __retentionAlive('constructor-binding')
        and not __retentionAlive('constructor-body'))
    for _,mode in ipairs({'completed','stopped','failed','force-cancelled'}) do
        check('disposal_player_'..mode:gsub('-','_')..'_binding_collected',not __retentionAlive('player-'..mode..'-binding'))
    end
    check('disposal_npc_completed_binding_collected',not __retentionAlive('npc-completed-binding'))
    check('disposal_original_queue_waits_for_native_ack',__retentionAlive('npc-pending-binding'))
    check('disposal_abandoned_offer_retained_until_expiry',__retentionAlive('offer-abandoned') and __retentionAlive('offer-abandoned-body'))
    check('disposal_replaced_offer_collected',not __retentionAlive('offer-replaced') and not __retentionAlive('offer-replaced-body'))
    check('disposal_dead_offer_collected',not __retentionAlive('offer-dead') and not __retentionAlive('offer-dead-body'))
    __retentionKeptActions.pending.character.holdCancellation=false
    W.retryCancellations()
    check('disposal_acknowledged_native_binding_tombstone',__retentionKeptActions.pending._SAOWindowRepairBinding==false)
    for _,callback in ipairs(Events.OnTick.callbacks) do if callback==W.expireOffers then callback() end end
    check('disposal_tick_expires_abandoned_offers',W.offerCount()==0)
end

function __finishWindowDisposal()
    local W,check,fixture=SAO.WindowRepair,__windowCheck,__windowFixture
    __retentionCollect()
    check('disposal_acknowledged_native_binding_collected',not __retentionAlive('npc-pending-binding'))
    check('disposal_expired_offer_and_body_collected',not __retentionAlive('offer-abandoned') and not __retentionAlive('offer-abandoned-body'))
    local capacity=true
    for i=1,128 do local f=fixture('disposal-cap-'..i);capacity=capacity and W.offer(f.id,f.body)~=nil end
    local excess=fixture('disposal-cap-129')
    check('disposal_offer_capacity_is_bounded',capacity and W.offerCount()==128 and W.offer(excess.id,excess.body)==nil)
    W.forget('disposal-cap-1')
    check('disposal_offer_forget_releases_capacity',W.offerCount()==127 and W.offer(excess.id,excess.body)~=nil)
    W.reset('disposal-world-reset')
    check('disposal_world_reset_clears_all_offers',W.offerCount()==0)
    __windowResults=table.concat(__checks,'\n')
end
