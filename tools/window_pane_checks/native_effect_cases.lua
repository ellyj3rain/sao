-- Production primitive on real native cell/window/inventory/factory receivers.
-- Shared guard wrapper/ordinary queue and private owners are qualified separately.
local A=SAO.WindowPaneAction
local function check(name,value) __print(name,value==true);if value~=true then error(name) end end
local function setup(open)
    __reset(open);__sent=0
    local character={getInventory=function() return __inventory end,isTimedActionInstant=function() return false end}
    return A:new(character,__window)
end
for _,open in ipairs({false,true}) do
    local a=setup(open)
    local label=open and 'open' or 'closed'
    check('native_'..label..'_before_flags',__window:isSmashed() and __window:isGlassRemoved() and __window:getHealth()==7)
    check('native_'..label..'_start',a:isValidStart()==true)
    check('native_'..label..'_complete',a:complete(__first)==true)
    check('native_'..label..'_flags_and_max_health',not __window:isSmashed() and not __window:isGlassRemoved() and __window:getHealth()==__maxHealth and __maxHealth>7)
    check('native_'..label..'_correct_sprite',__window:getSprite()==(open and __open or __closed))
    check('native_'..label..'_lock_open_identity',__window:IsOpen()==open and __window:isLocked() and __window:isPermaLocked() and __window:getKeyId()==492 and __window:getObjectIndex()==0)
    check('native_'..label..'_navigation_refresh',__navCount()>0)
    check('native_'..label..'_exact_one_payment',not __inventory:contains(__first) and __inventory:contains(__second) and __inventory:contains(__wrong) and __inventory:getItems():size()==2 and __sent==1)
    check('native_'..label..'_repeated_inert',a:complete(__second)==false and __inventory:contains(__second) and __sent==1)
end
local a=setup(false)
check('native_wrong_material_inert',a:complete(__wrong)==false and __window:isSmashed() and __inventory:getItems():size()==3 and __navCount()==0)
__inventory:Remove(__first)
check('native_removed_exact_material_inert',a:complete(__first)==false and __window:isSmashed() and __inventory:contains(__second) and __navCount()==0)
