-- Actual owned producer/owner functions in installed VM; actor/window/root
-- inventory and queue dispatch controlled, matching native type-only/eval lookup.
local function check(name,value)__windowCheck(name,value)end
local function fixture(id,human)
    local f=__windowFixture('pane-owner-correction-'..id)
    if human then f.body.md={};f.body.shell=false end
    f.pane.consumed=true
    local free={};for key,value in pairs(f.pane)do free[key]=value end
    free.id=714;free.consumed=false;free.container=f.inventory
    f.inventory.items={f.pane,free};f.free=free
    return f
end
local function noEffects(f)
    return f.window.smashed and f.window.glass and f.window.synced==nil
end
function __runPaneOwnerCorrections()
    local W,A=SAO.WindowRepair,SAO.WindowPaneAction
    check('correction_owned_guard_installs',W.install()==true)
    local f=fixture('human-root-order',true)
    local a=A:new(f.body,f.window)
    ISTimedActionQueue.add(a)
    check('human_root_reserved_first_free_second_admits',a:isValidStart()==true)
    check('human_root_free_exact_payment',a:complete()==true and not f.inventory:contains(f.free)
        and f.inventory:contains(f.pane) and #f.inventory.items==1 and f.inventory.sent==1)
    a:perform()
    f=fixture('npc-root-order',false)
    local offer=W.offer(f.id,f.body)
    local admitted=offer and W.begin(f.id,f.body,offer)==true
    check('npc_root_reserved_first_free_second_admits',admitted==true)
    if admitted then
        a=ISTimedActionQueue.getTimedActionQueue(f.body).current
        check('npc_root_pins_free_exact_item',f.rec.windowRepairWork.itemId=='714' and a:isValidStart()==true)
        check('npc_root_free_exact_payment',a:complete()==true and not f.inventory:contains(f.free)
            and f.inventory:contains(f.pane) and W.outcome(f.id,1).itemId=='714' and f.inventory.sent==1)
        a:perform();W.active(f.id,f.body)
    end
    f=fixture('human-only-reserved',true);f.inventory.items={f.pane}
    a=A:new(f.body,f.window);ISTimedActionQueue.add(a)
    check('human_sole_reserved_start_refuses',a:isValidStart()==false)
    check('human_sole_reserved_completion_inert',a:complete()==false and noEffects(f) and f.inventory:contains(f.pane))
    a:stop()
    f=fixture('npc-only-reserved',false);f.inventory.items={f.pane}
    offer=W.offer(f.id,f.body)
    check('npc_sole_reserved_admission_refuses',offer~=nil and W.begin(f.id,f.body,offer)==false
        and noEffects(f) and f.inventory:contains(f.pane) and f.rec.windowRepairWork==nil)
    f=fixture('human-free-identity',true);a=A:new(f.body,f.window);ISTimedActionQueue.add(a)
    check('root_eligible_exact_identity_pinned',a:isValidStart()==true)
    local replacement={};for k,v in pairs(f.free)do replacement[k]=v end
    f.inventory.items={f.pane,replacement}
    check('root_sameid_eligible_substitution_refuses',a:complete()==false and noEffects(f)
        and f.inventory:contains(f.pane) and f.inventory:contains(replacement) and f.inventory.sent==nil)
    a:stop()
    __windowResults=table.concat(__checks,'\n')
end
