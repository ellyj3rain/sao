-- Selected acquired sources join NewMusic's original operator scheduling pass.
SAO=SAO or {}
SAO.LeisureMusicWorld=SAO.LeisureMusicWorld or {}
local W=SAO.LeisureMusicWorld
if W.reset then W.reset() end
local installed,scope
local function shallow(value)
 local out={} for key,v in pairs(value or {})do out[key]=v end return out
end
local function finite(n)return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function intact()
 if not installed then return false end
 for name,seal in pairs(installed.seals)do
  if _G[name]~=seal.table then return false end
  for key,fn in pairs(seal.functions)do
   local expected=fn
   if name=="NMClientDetachedPlaybackPass" and key=="run" then expected=installed.runWrapper end
   if name=="NMClientWorldSourceCache" and key=="collectInRange" then expected=installed.collectWrapper end
   if name=="NMClientSPLocalRuntime" and key=="emitZombiePulses" then expected=installed.pulseWrapper end
   if seal.table[key]~=expected then return false end
  end
 end
 for name,seal in pairs(installed.dependencies)do
  if _G[name]~=seal.table then return false end
  for key,fn in pairs(seal.functions)do if seal.table[key]~=fn then return false end end
 end
 return true
end
function W.current()return intact()end
local function match(row,entry)
 if type(row)~="table"or type(row.state)~="table"or type(row.source)~="table"or type(row.uuid)~="string"then return false end
 local state,source=entry and entry.stateSnapshot,entry and entry.source
 if not state or not source or tostring(state.deviceUUID)~=row.uuid
  or source.context~=row.context then return false end
 for _,key in ipairs({"revision","playbackEpoch","sourceGeneration","trackIndex","mediaFullType"})do
  if state[key]~=row.state[key]then return false end
 end
 for _,key in ipairs({"x","y","z"})do
  if not finite(source[key])or not finite(row.source[key])or math.abs(source[key]-row.source[key])>.01 then return false end
 end
 if row.context=="vehicle" then
  if tostring(source.vehicleId)~=tostring(row.source.vehicleId)
   or tostring(source.vehicleSqlId)~=tostring(row.source.vehicleSqlId)
   or tostring(entry.partId or entry.attachedPartId)~=tostring(row.source.partId)then return false end
 end
 return true
end
function W.install(audited,candidates,captureEnding)
 if installed then return intact() end
 if isClient()or isServer()or type(candidates)~="function"or type(captureEnding)~="function"then return false end
 local seals={}
 for name,expected in pairs(audited or {})do
  local public=_G[name]
  if type(public)~="table"then return false end
  local functions={}
  for key,fn in pairs(expected)do
   if type(fn)=="function"then
    if type(public[key])~="function"or not SAOJavaBridge:sameNativeLuaSourceFunction(public[key],fn)
     or not SAOJavaBridge:nativeLuaSourceFunctionUsesEnvironment(public[key],_G)then return false end
    functions[key]=public[key]
   end
  end
  seals[name]={table=public,functions=functions}
 end
 for _,name in ipairs({"NMClientDetachedPlaybackPass","NMClientWorldSourceCache","NMPlaybackRuntime",
  "NMPlaybackRuntimeCommon","NMClientSPLocalRuntime","NMClientTrackFinishedDispatch","NMClientPlaybackTick","NMClientMainRuntime"})do
  if not seals[name]then return false end
 end
 local mandatory={NMClientDetachedPlaybackPass="run",NMClientWorldSourceCache="collectInRange",
  NMPlaybackRuntime="syncDevice",NMPlaybackRuntimeCommon="updateTrackEndState",
  NMClientSPLocalRuntime="emitZombiePulses",NMClientTrackFinishedDispatch="consumeAndDispatchTrackFinished",
  NMClientPlaybackTick="onTick",NMClientMainRuntime="onTick"}
 for name,key in pairs(mandatory)do if not seals[name].functions[key]then return false end end
 local originalRun=NMClientDetachedPlaybackPass.run
 local originalCollect=NMClientWorldSourceCache.collectInRange
 local originalPulse=NMClientSPLocalRuntime.emitZombiePulses
 local dependencies={}
 -- Exact dependency bindings are kept separately from audited executable shapes.
 -- Their initial source lineage is supplied by the installed source qualification.
 for name,value in pairs(_G)do
  if type(name)=="string"and name:find("^NM")and type(value)=="table"and not seals[name]then
   local functions={}for key,fn in pairs(value)do if type(fn)=="function"then functions[key]=fn end end
   dependencies[name]={table=value,functions=functions}
  end
 end
 local binding={seals=seals,dependencies=dependencies,candidates=candidates,captureEnding=captureEnding}
 local function selected()
  local ok,rows=pcall(candidates);return ok and type(rows)=="table"and rows or {}
 end
 binding.collectWrapper=function(player,out)
  originalCollect(player,out)
  if not scope or scope.player~=player or not intact()or type(out)~="table"then return end
  local seen={} for _,row in ipairs(out)do if row.uuid then seen[tostring(row.uuid)]=true end end
  local cap=math.max(0,tonumber(NMRuntimeConfig.getMaxActiveWorldSourcesPerClient())or 10)
  for _,row in ipairs(selected())do
   if #out>=cap then break end
   if not seen[row.uuid]then
    local entry=NMClientWorldSourceCache.get(row.uuid)
    if entry and row.context=="vehicle"then entry=NMClientWorldSourceCache.refreshVehicleSource(row.uuid)or entry end
    if match(row,entry)then
     out[#out+1]={uuid=row.uuid,entry=shallow(entry),profile=row.profile,
      distSq=(player:getX()-row.source.x)^2+(player:getY()-row.source.y)^2}
     seen[row.uuid]=true;scope.selected[row.uuid]=row
    end
   end
  end
 end
 binding.runWrapper=function(player,options)
  if not intact()or player~=getPlayer()or type(options)~="table"
   or type(options.consumeAndDispatchTrackFinished)~="function"then return originalRun(player,options)end
  local previous=scope;local callback=options.consumeAndDispatchTrackFinished
  scope={player=player,selected={}}
  options.consumeAndDispatchTrackFinished=function(p,profile,state,entry,item,kind,uuid)
   if intact()then pcall(captureEnding,tostring(uuid))end
   return callback(p,profile,state,entry,item,kind,uuid)
  end
  local ok,result=pcall(originalRun,player,options)
  options.consumeAndDispatchTrackFinished=callback;scope=previous
  if not ok then error(result)end
  return result
 end
 binding.pulseWrapper=function(player,pulseCandidates,state)
  originalPulse(player,pulseCandidates,state)
  if not intact()or player~=getPlayer()or not state or not state.zombieAttractionPulseState then return end
  -- Original pulse authority and its shared UUID state deduplicate all listeners.
  for _,row in ipairs(selected())do
   local candidate=pulseCandidates and pulseCandidates[row.uuid]
   local cached=NMClientWorldSourceCache.get(row.uuid)
   if candidate and cached and match(row,{stateSnapshot=candidate.state,source=candidate.source,
    partId=cached.partId,attachedPartId=cached.attachedPartId})then
    pcall(originalPulse,row.body,{[row.uuid]=candidate},state)
   end
  end
 end
 installed=binding
 NMClientDetachedPlaybackPass.run=binding.runWrapper
 NMClientWorldSourceCache.collectInRange=binding.collectWrapper
 NMClientSPLocalRuntime.emitZombiePulses=binding.pulseWrapper
 return intact()
end
function W.reset()
 if installed then
  local restore={NMClientDetachedPlaybackPass={"run",installed.runWrapper},
   NMClientWorldSourceCache={"collectInRange",installed.collectWrapper},NMClientSPLocalRuntime={"emitZombiePulses",installed.pulseWrapper}}
  for name,pair in pairs(restore)do
   local seal=installed.seals[name]
   if _G[name]==seal.table and seal.table[pair[1]]==pair[2]then seal.table[pair[1]]=seal.functions[pair[1]]end
  end
 end
 installed=nil;scope=nil
end
