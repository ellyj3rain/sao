-- Controlled identity/time/event storage around actual native scene/owners.
__hours=100
local stores={}
ModData={get=function(k)return stores[k]end,getOrCreate=function(k)stores[k]=stores[k] or {};return stores[k]end}
Events=setmetatable({}, {__index=function(t,k)local v={Add=function()end,Remove=function()end};rawset(t,k,v);return v end})
SAO=SAO or {}
SAO.Log={line=function()end}
SAO.History={countyHours=function()return __hours end,record=function()end}
SAO.Identity={records={},get=function(id)return SAO.Identity.records[id]end}
SAO.Body={active={},foreign={},get=function(id)return SAO.Body.active[id]end}
SAO.Disposition={traits=function()return {discipline=.5,initiative=.5,selfPreservation=.5}end,
 fleeDistance=function()return 6 end,eatAt=function()return .8 end,drinkAt=function()return .8 end,
 describe=function()return 'controlled person traits'end}
SAO.Hash={unit=function()return .75 end}
SAOJavaBridge=__bridge
function getDebug()return false end
function getGameSpeed()return 1 end
function getTimestampMs()return __hours*3600000 end
function getTimestamp()return __hours*3600 end
function getGameTime()return {getWorldAgeHours=function()return __hours end}end
SandboxVars={SurvivorAwareness={}}
ISInventoryPage={}
function __case(k,v)__check(k,v==true)end

-- Capture the actual existing public projection, without changing its schema.
function __projection(label,id)
 local function quoted(v)return '"'..tostring(v):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'end
 local encode
 encode=function(v)
  if type(v)=='string' then return quoted(v) end
  if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
  if type(v)~='table' then return 'null'end
  local entries={};if #v>0 then for _,x in ipairs(v)do entries[#entries+1]=encode(x)end;return '['..table.concat(entries,',')..']'end
  for k,x in pairs(v)do entries[#entries+1]=quoted(k)..':'..encode(x)end;return '{'..table.concat(entries,',')..'}'
 end
 local full=SAO.Cognition.snapshot(id,true);local bounded=SAO.Cognition.snapshot(id,false)
 __case(label..'_actual_public_projection',full~=nil and bounded~=nil)
 print('PROJECTION_'..label..'_FULL',encode(full));print('PROJECTION_'..label..'_BOUNDED',encode(bounded))
end
