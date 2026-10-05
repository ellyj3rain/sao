local P, G = SAO.Perception, SAO.Gesture
SAO.History.countyHours = function() return __nativeHours() + 240 end
local function setup(hidden)
    __clock(12); fresh(); __pulseReset(); __deaf(false)
    __other:setAsleep(false); __other:getModData().SAOPersonId = "listener"
    __other:getModData().SAOExternalToken = nil
    __records.listener = { id = "listener" }; SAO.Body.active.listener = __other
    SAO.Controller.agents.listener = {rec=__records.listener,state="IDLE"}
    __moveListener(16.5,20.5,hidden and 1 or -1,0)
    local action = queueBlow(); local work = G.instrumentWork("person")
    return action, work, G.instrumentOccurrence("person",work.workId)
end
local function claim(work, who, body)
    return P.acquireInstrumentHearing(who or "listener",body or __other,"person",work.workId)
end
check("actual_owned_native_emission_has_detached_occurrence",function()
    local action,work,row=setup()
    if not row or not __nativeVisible() or row.actorId~="person" or row.workId~=work.workId
        or row.clock~="native-world-age-hours" or row.emittedAtHours~=__nativeHours() then return false end
    row.workId="forged"
    return G.instrumentOccurrence("person",work.workId).workId==work.workId
end)
check("emission_alone_is_not_hearing",function()
    local action,work=setup(); return claim(work)==nil
end)
check("scanner_hearing_and_visible_emitter_create_once_private_receipt",function()
    local action,work,pulse=setup(); local scan=__scan(__other)
    print("SCANNER "..tostring(scan).." visible="..tostring(__nativeVisible()))
    local row=claim(work)
    if not row or not string.find(scan,":cue:"..pulse.pulseId,1,true)
        or row.observerId~="listener" or row.actorId~="person" or row.workId~=work.workId
        or row.acquiredAtCountyHours~=__nativeHours()+240 or row.heardAtHours~=__nativeHours()
        or row.witnessedAtHours~=__nativeHours() or row.status~=nil then return false end
    row.actorId="forged"
    return claim(work)==nil and SAOJavaBridge:claimInstrumentHearing(__other,__body,work.workId,pulse.pulseId)==nil
        and P.instrumentHearing("listener","person",work.workId).actorId=="person"
        and __records.person.instrumentHearings==nil and #__records.listener.instrumentHearings==1
end)
check("audible_unseen_emitter_stays_anonymous",function()
    local action,work,pulse=setup(true);local scan=__scan(__other)
    return not __nativeVisible() and string.find(scan,":cue:"..pulse.pulseId,1,true)~=nil and claim(work)==nil
end)
check("seeing_later_does_not_relabel_past_anonymous_acquisition",function()
    local action,work=setup(true);__scan(__other);__moveListener(16.5,20.5,-1,0)
    return __nativeVisible() and claim(work)==nil
end)
check("current_visibility_loss_refuses_attribution",function()
    local action,work=setup();__scan(__other);__moveListener(16.5,20.5,1,0);return claim(work)==nil
end)
check("deaf_listener_refuses_even_after_earlier_hearing",function()
    local action,work=setup();__scan(__other);__deaf(true);return claim(work)==nil
end)
check("asleep_listener_never_acquires_sound",function()
    local action,work,pulse=setup();__other:setAsleep(true);local scan=__scan(__other)
    return not string.find(scan,":cue:"..pulse.pulseId,1,true) and claim(work)==nil
end)
check("asleep_after_acquisition_refuses_current_claim",function()
    local action,work=setup();__scan(__other);__other:setAsleep(true);return claim(work)==nil
end)
check("unacquired_wrong_work_or_performer_refused",function()
    local action,work,pulse=setup();__scan(__other)
    return SAOJavaBridge:claimInstrumentHearing(__other,__body,"instrument:person:999",pulse.pulseId)==nil
        and SAOJavaBridge:claimInstrumentHearing(__body,__other,work.workId,pulse.pulseId)==nil
        and P.acquireInstrumentHearing("listener",__other,"person","instrument:person:999")==nil
end)
check("current_body_and_token_custody_required",function()
    local action,work=setup();__scan(__other);SAO.Body.active.listener=__body
    if claim(work)~=nil then return false end
    SAO.Body.active.listener=__other;__records.listener.bodyOwnerToken="foreign"
    return claim(work)==nil
end)
check("performer_generation_change_refuses_native_claim",function()
    local action,work,pulse=setup();__scan(__other);__body:getModData().SAOExternalToken="foreign"
    return SAOJavaBridge:claimInstrumentHearing(__other,__body,work.workId,pulse.pulseId)==nil
end)
check("later_visible_audible_rescan_retains_distinct_acquisition_dates",function()
    local action,work,pulse=setup(true);__scan(__other)
    __clock(12.01);__moveListener(16.5,20.5,-1,0);__scan(__other)
    local row=claim(work)
    return row and row.heardAtHours==pulse.emittedAtHours and row.witnessedAtHours>row.heardAtHours
        and row.witnessedAtHours==__nativeHours() and row.atHours==row.witnessedAtHours
end)
check("listener_generation_cannot_consume_old_acquisition",function()
    local action,work,pulse=setup();__scan(__other);__other:getModData().SAOExternalToken="next-generation"
    __records.listener.bodyOwnerToken="next-generation"
    return claim(work)==nil and SAOJavaBridge:claimInstrumentHearing(__other,__body,work.workId,pulse.pulseId)==nil
end)
check("exact_emission_cannot_rebind_wrong_body_or_work",function()
    local action,work=setup();local emitted=__lastSound()
    return SAOJavaBridge:bindInstrumentOccurrence(__other,emitted,"instrument:listener:1")==nil
        and SAOJavaBridge:bindInstrumentOccurrence(__body,emitted,"instrument:person:999")==nil
end)
check("receipt_replay_refuses_after_native_heard_cache_eviction",function()
    local action,work,pulse=setup();__scan(__other);if not claim(work) then return false end
    __evictHeard()
    return SAOJavaBridge:claimInstrumentHearing(__other,__body,work.workId,pulse.pulseId)==nil
end)
check("native_pool_reuse_invalidates_old_occurrence",function()
    local action,work=setup();__scan(__other);local reused=__recycle();__scan(__other)
    return reused and claim(work)==nil
end)
check("native_clock_reversal_and_expiry_refuse",function()
    local action,work=setup();__scan(__other);__clock(11.99)
    if claim(work)~=nil then return false end
    __clock(12.06);return claim(work)==nil
end)
check("world_reset_invalidates_runtime_not_retained_memory",function()
    local action,work=setup();__scan(__other);local row=claim(work)
    if not row then return false end
    __records.listener=__roundTrip(__records.listener);__pulseReset()
    local stored=P.instrumentHearing("listener","person",work.workId)
    return stored and stored.pulseId==row.pulseId and claim(work)==nil
end)
check("malformed_or_future_receipt_cannot_become_private_evidence",function()
    local action,work=setup();__scan(__other);local native=SAOJavaBridge
    SAOJavaBridge={isShell=function(self,body)return native:isShell(body) end,
        claimInstrumentHearing=function(self,body,performer,key,pulse)
            local row=native:claimInstrumentHearing(body,performer,key,pulse)
            if row then row.atHours=__nativeHours()+1 end;return row
        end}
    local value=claim(work);SAOJavaBridge=native
    return value==nil and __records.listener.instrumentHearings==nil
end)
check("retained_receipt_rejects_future_dates_and_foreign_identity",function()
    local action,work=setup();__scan(__other);if not claim(work) then return false end
    local row=__records.listener.instrumentHearings[1];local at=row.atHours
    row.atHours=__nativeHours()+1
    if P.instrumentHearing("listener","person",work.workId)~=nil then return false end
    row.atHours=at;row.observerId="foreign"
    return P.instrumentHearing("listener","person",work.workId)==nil
end)
check("new_occurrence_does_not_replay_previous_receipt",function()
    local action,work,old=setup();__scan(__other);if not claim(work) then return false end
    action:update();__emitter:finish();action:update();action:perform();__finishNativeAction(action.action)
    local nextAction=queueBlow();local nextWork=G.instrumentWork("person")
    if not nextWork or nextWork.workId==work.workId or claim(nextWork)~=nil then return false end
    __scan(__other);local row=claim(nextWork)
    return row and row.pulseId~=old.pulseId and #__records.listener.instrumentHearings==2
end)
check("bounded_receipts_omit_old_rows_without_granting_shared_outcomes",function()
    local action,work=setup()
    for i=1,19 do
        __scan(__other);if not claim(work) then return false end
        action:update();__emitter:finish();action:update();action:perform();__finishNativeAction(action.action)
        if i<19 then action=queueBlow();work=G.instrumentWork("person") end
    end
    return #__records.listener.instrumentHearings==16 and __records.listener.instrumentHearingsOmitted==3
        and __records.listener.conceptKnowledge==nil
        and __records.listener.proceduralPlanning==nil
end)
