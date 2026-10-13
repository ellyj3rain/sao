require "SAO_ElectricalService"
require "SAO_HouseholdService"
SAO=SAO or {};SAO.ElectricalMenu=SAO.ElectricalMenu or{}
local M,E=SAO.ElectricalMenu,SAO.ElectricalService
local selected=setmetatable({},{__mode="k"})
local function choose(body,generator,consumer,operation)return E.beginHuman(body,generator,consumer,operation)end
local function selectGenerator(body,generator)selected[body]=generator end
function M.fill(player,context,objects,test)
 if test or isClient()or isServer()then return end
 local body=getSpecificPlayer(player);if not body or E.reconcileHuman(body)~=true then return end
 for _,object in ipairs(objects or{})do
  if instanceof(object,"IsoGenerator")and object:getObjectIndex()~=-1 then
   context:addOption("Select generator for appliance service",body,selectGenerator,object)
   if object:isActivated()then context:addOption("Open generator breaker",body,choose,object,object,"breaker-open")
   elseif E.breakerOpen(object)and object:getSquare():isOutside()and object:isConnected()and object:getFuel()>0 and object:getCondition()>0 then
    context:addOption("Reset generator breaker",body,choose,object,object,"breaker-reset")
   end
  elseif selected[body]and object:getObjectIndex()~=-1 and object:couldBePoweredByGenerator()then
   local sample=E.measure(body,selected[body],object,{sourceId="human-direct",fingerprint="human-direct"})
   if sample then
    context:addOption("Inspect electrical service",body,choose,selected[body],object,"inspect-load")
    if sample.switchable and sample.consumerActive then context:addOption("Switch off appliance load",body,choose,selected[body],object,"shed-load")end
   end
  end
 end
end
if Events and Events.OnFillWorldObjectContextMenu then
 if M.onMenu then Events.OnFillWorldObjectContextMenu.Remove(M.onMenu)end
 M.onMenu=M.fill;Events.OnFillWorldObjectContextMenu.Add(M.onMenu)
end
if Events and Events.OnGameStart then
 if M.onStart then Events.OnGameStart.Remove(M.onStart)end
 M.onStart=function()selected=setmetatable({},{__mode="k"});for i=0,3 do local b=getSpecificPlayer(i);if b then E.reconcileHuman(b)end end end
 Events.OnGameStart.Add(M.onStart)
end
return M
