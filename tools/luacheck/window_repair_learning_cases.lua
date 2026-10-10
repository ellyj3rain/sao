-- Actual completion owner, private receiver, independent models and native table replay.
function __runWindowLearning()
    local W,C = SAO.WindowRepair,SAO.Cognition
    local fixture,admitted,check = __windowFixture,__windowAdmitted,__windowCheck
    local store = {}
    ModData = {get=function(key) return store[key] end,
        getOrCreate=function(key) store[key]=store[key] or {}; return store[key] end}
    SAO.Identity.all=function() return __records end
    local function equal(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then return a==b end
        for key,value in pairs(a) do if not equal(value,b[key]) then return false end end
        for key in pairs(b) do if a[key]==nil then return false end end
        return true
    end
    local function disable() store.SurvivorAwareness_Cognition={settings={enabled=false}} end
    local function noExperience(rec)
        local s=rec.cognition
        return s==nil or (#s.experiences==0 and s.eventSequence==0
            and s.models.ordinary.revision==0 and s.models.associative.revision==0)
    end
    local function fireMinute()
        for _,callback in ipairs(Events.EveryOneMinute.callbacks) do callback() end
    end
    local function noGoalCredit(s)
        if not s then return false end
        for _,name in ipairs({'ordinary','associative'}) do
            for _,goal in ipairs({'food','water','inspect','continue'}) do
                if s.models[name].beliefs['goal:'..goal]~=nil then return false end
            end
        end
        return true
    end
    __hours=200
    local f=fixture('learning-disabled')
    local action=admitted(f)
    check('window_admission_has_no_private_experience',noExperience(f.rec))
    __nativeOp('reset');f.window.mirror=true;f.inventory.mirror=true
    check('window_disabled_learning_preserves_physical_completion',action:complete()==true
        and __nativeOp('poststate') and W.outcome(f.id,1).planningAcknowledged==true)
    check('window_disabled_learning_retains_unacknowledged_result',W.outcome(f.id,1).learningAcknowledged~=true
        and noExperience(f.rec))
    action:perform();W.active(f.id,f.body)
    C.configure(.5,12,3)
    for _=1,8 do fireMinute() end
    local s=f.rec.cognition
    check('window_replay_delivers_private_experience',s and #s.experiences==1
        and s.experiences[1].id==f.id..'/window-result/1' and W.outcome(f.id,1).learningAcknowledged==true)
    local x=s and s.experiences[1] or {}
    check('window_native_private_projection',x.kind=='window-repair' and x.perspective=='performed'
        and x.sourceId==W.outcome(f.id,1).entryKey and x.itemId==713
        and x.bodyToken==nil and x.world==nil and x.nativeAttempted==nil and x.paneConsumed==nil)
    check('window_native_independent_memories',s and s.models.ordinary.revision==1
        and s.models.associative.revision==1
        and s.models.ordinary.beliefs['direct:window-repair:'..x.sourceId..':'..x.itemType]~=nil
        and s.models.associative.beliefs['relation:transform:broken-glass:'..x.sourceId..':repaired-glass:'..x.sourceId]~=nil)
    check('window_private_experience_has_no_execution_credit',s and #s.episodes==0 and s.sequence==0 and noGoalCredit(s))
    local prior=__nativeRoundtrip(s or {})
    __hours=201;W.flush(f.id);W.deliverLearning(f.id)
    check('window_learning_duplicate_is_inert',equal(prior,f.rec.cognition)
        and f.rec.cognition.experiences[1] and f.rec.cognition.experiences[1].worldHours==200)
    f.rec=__nativeRoundtrip(f.rec);__records[f.id]=f.rec;C.rebindWorld()
    f.rec.windowRepair.outcomes['1'].learningAcknowledged=nil
    prior=__nativeRoundtrip(f.rec.cognition or {});__hours=202
    for _,callback in ipairs(Events.OnGameStart.callbacks) do callback() end
    for _=1,8 do fireMinute() end
    check('window_native_restore_replay_is_inert',equal(prior,f.rec.cognition)
        and W.outcome(f.id,1).learningAcknowledged==true and __nativeOp('poststate'))
    local immediate=fixture('learning-immediate');local ia=admitted(immediate)
    check('window_completion_private_join',ia:complete()==true and immediate.rec.cognition
        and #immediate.rec.cognition.experiences==1 and W.outcome(immediate.id,1).learningAcknowledged==true)
    ia:perform();W.active(immediate.id,immediate.body)
    local interrupted=fixture('learning-interrupted');local stopped=admitted(interrupted)
    interrupted.inventory:Remove(interrupted.pane);stopped:complete()
    check('window_interrupted_work_has_no_private_experience',noExperience(interrupted.rec)
        and W.outcome(interrupted.id,1).status=='interrupted')
    local faulty=fixture('learning-fault');local fa=admitted(faulty)
    local receiver=C.windowRepairOutcome
    C.windowRepairOutcome=function() error('controlled unavailable private receiver') end
    local physical=fa:complete();C.windowRepairOutcome=receiver
    check('window_learning_fault_retains_result',physical==true and not faulty.window.smashed
        and noExperience(faulty.rec) and W.outcome(faulty.id,1).learningAcknowledged~=true)
    fa:perform();W.active(faulty.id,faulty.body)
    for _=1,8 do fireMinute() end
    check('window_learning_fault_retries_exact_completion',faulty.rec.cognition
        and #faulty.rec.cognition.experiences==1 and W.outcome(faulty.id,1).learningAcknowledged==true)
    local oldPlanner=SAO.ProceduralPlanning;SAO.ProceduralPlanning=nil
    faulty.rec.windowRepair.outcomes['1'].learningAcknowledged=nil;W.flush(faulty.id)
    check('window_learning_retry_is_independent_of_planner',W.outcome(faulty.id,1).learningAcknowledged==true)
    SAO.ProceduralPlanning=oldPlanner
    disable()
    local bounded=fixture('learning-bounded');local all=true
    for i=1,33 do
        bounded.window.smashed=true;bounded.window.glass=true
        bounded.inventory.items={bounded.pane};bounded.pane.container=bounded.inventory
        local a=admitted(bounded);all=all and a:complete()==true
        a:perform();W.active(bounded.id,bounded.body)
    end
    check('window_learning_retirement_records_omission',all and #bounded.rec.windowRepair.order==32
        and bounded.rec.windowRepair.learningOmitted==1 and W.outcome(bounded.id,1)==nil
        and noExperience(bounded.rec))
    bounded.rec.windowRepair.learningOmitted=-1
    check('window_malformed_learning_ledger_refuses_requery',W.outcome(bounded.id,33)==nil)
    C.configure(.5,12,3)
    local records=__records;__records={};W.reset('controlled-learning-scan')
    for i=1,350 do __records['scan-'..i]={id='scan-'..i} end
    local _,visits,owners=W.retryLearning()
    check('window_learning_scan_budget',visits==256 and owners==0)
    W.reset('controlled-learning-scan-reset')
    _,visits,owners=W.retryLearning()
    check('window_learning_reset_rebuilds_scan',visits==256 and owners==0)
    __records={}
    for i=1,70 do __records['owner-'..i]={id='owner-'..i,windowRepair={}} end
    local delivered,seen=W.deliverLearning,{}
    W.deliverLearning=function(id) seen[id]=true;return delivered(id) end
    _,visits,owners=W.retryLearning()
    check('window_learning_owner_budget',visits==32 and owners==32)
    W.retryLearning();W.retryLearning()
    local count=0;for _ in pairs(seen) do count=count+1 end
    check('window_learning_replay_is_fair',count==70)
    W.deliverLearning=delivered;__records=records;W.reset('controlled-learning-restored')
    __windowResults=table.concat(__checks,'\n')
end
