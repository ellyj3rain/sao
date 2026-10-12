-- Actual owned and optional context callbacks/native action queue. Bodies,
-- geometry, event loop/path scheduler and menu display remain controlled.
function getGameSpeed() return 1 end
ISInventoryPage={}
CharacterTrait={DEXTROUS='Dextrous',ALL_THUMBS='AllThumbs'}
function getText(key)return key end
function getSpecificPlayer()return __human end
function getCore()return {getBadHighlitedColor=function()return {} end,getGoodHighlitedColor=function()return {} end} end
ItemTag={CROWBAR='Crowbar'}
ISToolTip={new=function()return {} end}
ScriptManager={instance={getItem=function()return {getActualWeight=function()return .8 end} end}}
__removeWindow={queueNew=function()__removals=(__removals or 0)+1 end,canPerform=function()return true end,getWindowBreakChance=function()return 0 end}
local requireBase=require
function require(name)
    if name=='Starlit/utils/Colour' then return {fromColorInfo=function()return {1,1,1} end,lerpColour=function()return {1,1,1} end} end
    if name=='RepairableWindows/RemoveWindowAction' then return __removeWindow end
    if name=='RepairableWindows/AddWindowAction' and __optional then return __optional end
    return requireBase(name)
end
local function human(id)
    local f=__windowFixture('human-pane-'..id)
    f.body.md={};f.body.shell=false
    function f.body:getVehicle()return nil end
    function f.body:setPath2()end
    function f.body:getPerkLevel()return 3 end
    function f.body:getPathFindBehavior2()return {cancel=function()end} end
    function f.window:hasProperty()return false end
    function f.inventory:getFirstTypeEvalRecurse(t,predicate)return self:getFirstTypeEval(t,predicate)end
    function f.inventory:containsTagEvalRecurse()return self.hasCrowbar==true end
    function f.inventory:hasRoomFor()return true end
    __human=f.body;return f
end
local function menu()
    local m={options={}}
    function m:getOptionFromName()return nil end
    function m:addOption(label,target,callback,arg)
        local option={label=label,target=target,callback=callback,arg=arg};self.options[#self.options+1]=option;return option
    end
    return m
end
local function fill(f,m)
    for _,callback in ipairs(Events.OnFillWorldObjectContextMenu.callbacks)do callback(0,m,{f.window},false)end
end
local function check(name,value)__windowCheck(name,value)end
function __runPaneMenu()
    local prefix=__optional and 'optional' or 'standalone'
    local f=human(prefix);local m=menu();fill(f,m)
    check(prefix..'_normal_one_repair_entry',#m.options==1 and m.options[1].notAvailable~=true)
    local option=m.options[1]
    option.callback(option.target,option.arg)
    local q=ISTimedActionQueue.getTimedActionQueue(f.body)
    check(prefix..'_normal_native_walk_and_owned_repair',q.current.Type=='ISWalkToTimedAction' and #q.queue==2 and q.queue[2].Type=='SAOWindowPaneAction')
    q.current:perform()
    check(prefix..'_normal_guarded_repair_start',q.current.Type=='SAOWindowPaneAction' and q.current:isValidStart()==true)
    check(prefix..'_normal_native_completion',q.current:complete()==true and not f.window.smashed and #f.inventory.items==0)
    q.current:perform()
    check(prefix..'_normal_queue_terminal',q.current==nil and #q.queue==0 and SAO.WindowRepair.runtimeCount()==0)
    f=human(prefix..'-queue-change');SAO.WindowPaneMenu.queueNew(f.body,f.window)
    q=ISTimedActionQueue.getTimedActionQueue(f.body);q.current:perform();local a=q.current
    ISTimedActionQueue.queues[f.body]=nil
    local successor=ISTimedActionQueue.getTimedActionQueue(f.body)
    check(prefix..'_replaced_queue_complete_refuses',a:complete()==false and f.window.smashed and f.inventory:contains(f.pane) and successor.current==nil)
    a:stop()
    f=human(prefix..'-blocked');f.window.barricaded=true;m=menu();fill(f,m)
    check(prefix..'_barricaded_entry_disabled',#m.options==1 and m.options[1].notAvailable==true)
    check(prefix..'_barricaded_queue_refuses',SAO.WindowPaneMenu.queueNew(f.body,f.window)==false and #ISTimedActionQueue.getTimedActionQueue(f.body).queue==0)
    f=human(prefix..'-missing');f.inventory.items={};m=menu();fill(f,m)
    check(prefix..'_missing_material_no_entry',#m.options==0)
    if __optional then
        Perks={Woodwork={getName=function()return 'Carpentry' end}}
        f=human('removal-preserved');f.window.smashed=false;f.inventory.hasCrowbar=true;m=menu();fill(f,m)
        check('optional_original_removal_entry_retained',#m.options==1 and m.options[1].label=='IGUI_RepairableWindows_RemoveWindow')
        option=m.options[1];option.callback(option.target,option.arg)
        check('optional_original_removal_owner_retained',__removals==1)
        f=human('compatibility-callback');local a=__optional:new(f.body,f.window)
        check('optional_new_and_global_use_owned_producer',a.Type=='SAOWindowPaneAction' and _G[__optional.Type]==SAO.WindowPaneAction)
    end
    __windowResults=table.concat(__checks,'\n')
end
function __paneMenuReloadReceipt()
    local count=0
    for _,callback in ipairs(Events.OnFillWorldObjectContextMenu.callbacks)do if callback==SAO.WindowPaneMenu.fill then count=count+1 end end
    check('owned_menu_reload_has_one_callback',count==1)
    __windowResults=table.concat(__checks,'\n')
end
