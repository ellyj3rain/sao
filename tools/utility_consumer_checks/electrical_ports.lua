require=function()end
isClient=function()return false end;isServer=function()return false end
getCell=function()return body:getCell()end;getWorld=function()return __world end
getSpecificPlayer=function(i)return i==0 and body or nil end
getActivatedMods=function()return {contains=function()return false end}end
instanceof=function(object,name)return object and string.find(tostring(object),name,1,true)~=nil end
local g=__game..'/media/lua/'
local function load(path)return __load(path)end
load(g..'shared/ISBaseObject.lua');load(g..'shared/TimedActions/ISBaseTimedAction.lua');load(g..'client/TimedActions/ISTimedActionQueue.lua');load(g..'shared/TimedActions/ISActivateGenerator.lua');load(g..'shared/TimedActions/ISToggleStoveAction.lua');load(g..'shared/TimedActions/ISToggleLightAction.lua')
Events=Events or{}
SAO={History={countyHours=function()return __native('facts').hours end},HouseholdService={reservePlayerWorkSequence=function(b)local r=b:getModData();r.saoWorkSequence=(r.saoWorkSequence or 0)+1;return r.saoWorkSequence end},Needs={}}
SAO.Needs.queueVerified=function(a)ISTimedActionQueue.add(a);local q=ISTimedActionQueue.getTimedActionQueue(a.character);return q.current==a and q.queue[1]==a end
ISLogSystem={logAction=function()end}
IsoGenerator={isPoweringSquare=__coverage}
load(__unit..'/mod/42.20/media/lua/shared/SAO_ElectricalService.lua');load(__unit..'/mod/42.20/media/lua/client/SAO_ElectricalMenu.lua')
