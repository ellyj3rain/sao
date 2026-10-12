-- Actual installed LuaTimedActionNew Java perform/complete dispatch. Actor,
-- geometry and clock remain controlled; mirrored effect receivers are native.
local function check(name,value)__windowCheck(name,value)end
local function fixture(id,human)
    local f=__windowFixture('native-handoff-'..id)
    if human then f.body.md={};f.body.shell=false end
    return f
end
local function queue(f,human)
    local a
    if human then a=SAO.WindowPaneAction:new(f.body,f.window);ISTimedActionQueue.add(a)
    else a=__windowAdmitted(f) end
    __nativeDispatch(a,'bind')
    return a,ISTimedActionQueue.getTimedActionQueue(f.body)
end
local function nativePerform(a)__nativeDispatch(a,'perform')end
local function nativeComplete(a)__nativeDispatch(a,'complete')end
function __runNativePaneLifecycle()
    local W=SAO.WindowRepair
    check('native_lifecycle_installs',W.install()==true)
    for _,human in ipairs({true,false})do
        local kind=human and 'human' or 'npc'
        local f=fixture(kind,human);local a,q=queue(f,human)
        __nativeOp('reset');f.window.mirror=true;f.inventory.mirror=true
        nativePerform(a)
        check(kind..'_native_perform_retires_before_effect',q.current==nil and q:indexOf(a)==-1 and f.window.smashed and f.inventory:contains(f.pane))
        check(kind..'_native_perform_retains_binding',type(a._SAOWindowRepairBinding)=='function')
        nativeComplete(a)
        check(kind..'_native_complete_exact_payment',__nativeOp('poststate') and f.inventory.sent==1 and f.window.synced==1)
        check(kind..'_native_complete_retires_capsule',a._SAOWindowRepairBinding==false)
        if not human then
            local row=W.outcome(f.id,1)
            check('npc_native_canonical_result_and_private_feedback',row and row.status=='completed' and row.planningAcknowledged and row.learningAcknowledged and #f.rec.cognition.experiences==1)
            check('npc_native_runtime_retired',W.runtimeCount()==0)
        end
        nativeComplete(a);nativePerform(a)
        check(kind..'_native_late_replay_inert',f.inventory.sent==1 and f.window.synced==1 and q.current==nil)
        f=fixture(kind..'-successor',human);a,q=queue(f,human)
        local next=ISBaseTimedAction:new(f.body)
        function next:isValid()return true end
        ISTimedActionQueue.add(next)
        -- The controlled StartAction receiver records the successor's flags.
        local start=f.body.StartAction
        function f.body:StartAction(action)start(self,action);self:setIsFarming(true)end
        nativePerform(a)
        check(kind..'_native_legitimate_successor_started',q.current==next and q:indexOf(a)==-1 and f.body.farming==true)
        nativeComplete(a)
        check(kind..'_native_successor_preserved_after_effect',not f.window.smashed and f.inventory.sent==1 and q.current==next and f.body.farming==true)
        a:stop();nativeComplete(a)
        check(kind..'_native_late_callbacks_preserve_successor',q.current==next and f.body.farming==true and f.inventory.sent==1)
    end
    for _,case in ipairs({'queue','material','body','death','transfer','cancel'})do
        local f=fixture(case,false);local a,q=queue(f,false)
        nativePerform(a)
        if case=='queue' then ISTimedActionQueue.queues[f.body]=nil;ISTimedActionQueue.getTimedActionQueue(f.body)
        elseif case=='material' then f.inventory:Remove(f.pane)
        elseif case=='body' then f.body.md.SAOExternalToken='foreign-token'
        elseif case=='death' then f.rec.dead=true;f.body.dead=true
        elseif case=='transfer' then f.rec.zaoTransferPending={}
        elseif case=='cancel' then a:forceCancel() end
        nativeComplete(a)
        check('native_after_perform_'..case..'_refuses_effect',f.window.smashed and f.window.synced==nil and f.inventory.sent==nil)
    end
    local f=fixture('not-ended',true);local a,q=queue(f,true)
    a.action:setCurrentTime(0)
    nativePerform(a)
    check('native_early_perform_refuses',q.current==a and f.window.smashed and f.inventory:contains(f.pane))
    nativeComplete(a)
    check('native_unperformed_complete_refuses',f.window.smashed and f.inventory.sent==nil)
    __windowResults=table.concat(__checks,'\n')
end
