-- Furniture preparation uses the installed rest action and actual pose.
SAO=SAO or {}
SAO.LeisureSeating=SAO.LeisureSeating or {}
local S=SAO.LeisureSeating
if S.reset then S.reset('module-reload') end
local runtime={}
local PIN='dcd87cadfeb028770795a9a745ca8c2f4a866baf28c202a7ae654ad98bc92444'
local POSE_LIMIT_MS=15000
local function finite(x)return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function plain(x,depth)
 depth=depth or 0
 if type(x)=='string' or type(x)=='boolean'then return x end
 if type(x)=='number'then return finite(x) and x or nil end
 if type(x)~='table' or depth>=8 then return nil end
 local out={}for k,v in pairs(x)do if type(k)=='string' or type(k)=='number'then out[k]=plain(v,depth+1)end end
 return out
end
local function record(id)return SAO.Identity and SAO.Identity.get(id)end
local function provider(name)return name=='SAO.LeisureMusic' and SAO.LeisureMusic or nil end
local function now()
 local ok,value=pcall(getTimestampMs)
 return ok and finite(value) and value or nil
end
local function owned(a)
 return record(a.id)==a.record and SAO.Needs.ownsRecoveryBody(a.id,a.body)
  and a.body:getModData().SAOExternalToken==a.token and a.record.bodyOwner==a.bodyOwner
  and a.record.bodyOwnerToken==a.ownerToken
end
local function live(a)
 local o=a.offer
 local stamp=now()
 return runtime[a.id]==a and a.record.leisureSeating==a.row and a.row.status=='preparing' and owned(a)
  and stamp and stamp>=a.startedAtMs and stamp-a.startedAtMs<=POSE_LIMIT_MS
  and not a.body:isAsleep() and not a.body:getVehicle()
  and SAO.ProceduralPlanning.leisurePreparationPurpose(a.id,a.purposeId,a.ownerName,o.id,o.activity,o.sourceId,o.itemKey)~=nil
end
local function observation(id,body,key)
 local P=SAO.Perception
 for index,row in ipairs(P.leisureObjects(id,body)or{})do
  if index>96 then break end
  if row.actorId==id and row.key==key and row.kind=='object' and row.source=='native-personal-visibility'
   and type(row.runtimeInstance)=='string' then
   local object=P.resolveLeisureObject(id,body,key)
   if object and object:getSpriteName()==row.spriteName then return row,object end
  end
 end
end
local function identities(a)
 local r,piano=observation(a.id,a.body,a.offer.objectKey)
 local q,pair=observation(a.id,a.body,a.offer.pairObjectKey)
 local t,seat=observation(a.id,a.body,a.seatRow.key)
 return r and q and t and piano==a.piano and pair==a.pair and seat==a.seat
  and r.runtimeInstance==a.pianoRow.runtimeInstance and q.runtimeInstance==a.pairRow.runtimeInstance
  and t.runtimeInstance==a.seatRow.runtimeInstance and not seat:isFurnitureOccupied(a.body)
end
local function pianoReady(a)
 local here,there=a.body:getSquare(),a.piano:getSquare()
 return a.body:isSittingOnFurniture() and a.body:getVariableBoolean('SitOnFurnitureStarted') and a.body:getSitOnFurnitureObject()==a.seat
  and here and there and here:getZ()==there:getZ()
  and math.abs(here:getX()-there:getX())<=1 and math.abs(here:getY()-there:getY())<=1
  and not a.body:hasTrait(CharacterTrait.DEAF) and a.body:isFacingObject(a.piano,.8)
end
local function removeAction(a)
 if not a.action or not ISTimedActionQueue.hasAction(a.action) then return end
 local queue=ISTimedActionQueue.getTimedActionQueue(a.body)
 if queue.current==a.action then queue:onCompleted(a.action)else queue:removeFromQueue(a.action)end
end
local function finish(a,status,reason)
 a.row.status=status;a.row.reason=reason;a.row.endedAtHours=SAO.History.countyHours()
 a.row.nativeProgress={sourceStarted=a.started==true,sourceCompletionRequested=a.requested==true,
  sourcePerformed=a.performed==true,sourceCompleted=a.completed==true,actualSeated=owned(a) and a.body:isSittingOnFurniture()or false}
 runtime[a.id]=nil
end
function S.interrupt(id,body,reason)
 local a=runtime[id];local r=record(id)
 if a and a.body==body then
  if a.action then
   if owned(a)then
    a.action:stop()
    if not a.body:isSittingOnFurniture()and a.body:getSitOnFurnitureObject()==a.seat then a.native.interruptWaitToStart(a.action)end
   end
   if a.action.action then a.action:forceStop()end
   removeAction(a)
  end
  if a.route and SAO.Locomotion.jobs[id]==a.route then SAO.Locomotion.cancel(id)end
  finish(a,'interrupted',reason or 'seating interrupted');return true
 end
 if r and r.leisureSeating and r.leisureSeating.status=='preparing' and SAO.Needs.ownsRecoveryBody(id,body)then
  r.leisureSeating.status='interrupted';r.leisureSeating.reason=reason or 'native seating custody unavailable';return true
 end
 return false
end
local function restClass(a)
 local source=SAOJavaBridge:nativeLeisureActionSource('ISRestAction')
 if not source or source.className~='ISRestAction' or source.sha256~=PIN or type(source.sourceText)~='string'then return nil end
 local env={};env._G=env;setmetatable(env,{__index=_G})
 env.require=function(path)if path~='TimedActions/ISBaseTimedAction'then error('unaudited seating dependency')end end
 env.ISBaseTimedAction=ISBaseTimedAction:derive('SAOLeisureSeatingBase')
 env.ISBaseTimedAction.stop=function(self)if self==a.action and self.character==a.body then removeAction(a);self.character:setIsFarming(false)end end
 local fn=loadstring(source.sourceText,'native:ISRestAction');if not fn then return nil end
 setfenv(fn,env);fn();return env.ISRestAction
end
local function queue(a)
 if not live(a)or not identities(a)or not SAO.Needs.workAvailable(a.body)then return false end
 local class=restClass(a);if not class then return false end
 local act=class:new(a.body,a.seat,true)
 local native={waitToStart=act.waitToStart,interruptWaitToStart=act.interruptWaitToStart,start=act.start,
  update=act.update,perform=act.perform,complete=act.complete,stop=act.stop,forceComplete=act.forceComplete}
 a.action=act;a.native=native
 local function valid(self)return self==act and a.action==act and live(a)and identities(a)and self.character==a.body and self.bed==a.seat end
 act.isValid=function(self)return valid(self)end
 act.waitToStart=function(self)if not valid(self)or not ISTimedActionQueue.hasAction(self)then return true end;return native.waitToStart(self)end
 act.interruptWaitToStart=function(self)if self==act and owned(a)and a.body:getSitOnFurnitureObject()==a.seat then native.interruptWaitToStart(self)end end
 act.start=function(self)
  if not valid(self)or a.started or not ISTimedActionQueue.hasAction(self)then return end
  native.start(self);a.started=true;a.row.phase='awaiting-native-pose'
 end
 act.forceComplete=function(self)
  if valid(self)and a.started and a.inUpdate and ISTimedActionQueue.hasAction(self)then a.requested=true;native.forceComplete(self)end
 end
 act.update=function(self)
  if not valid(self)or not a.started or not ISTimedActionQueue.hasAction(self)then if self.action then self:forceStop()end;return end
  a.inUpdate=true;local ok,errorMessage=pcall(native.update,self);a.inUpdate=false
  if not ok then a.error=tostring(errorMessage);self:forceStop()end
 end
 act.perform=function(self)
  if not valid(self)or not a.started or not self.action or not self.action:isStarted()or not a.requested
   or a.performed or not ISTimedActionQueue.hasAction(self)then return end
  native.perform(self);a.performed=true
 end
 act.complete=function(self)
  if not valid(self)or not a.started or not a.performed or a.completed then return false end
  local result=native.complete(self);a.completed=result==true;return result
 end
 act.stop=function(self)
  if self~=act or a.action~=act or a.stopped then return end
  if owned(a)then native.stop(self)end;a.stopped=true
 end
 act.forceCancel=function(self)if self==act and a.action==act then a.stopped=true;removeAction(a)end end
 a.row.phase='native-rest';a.row.nativeSourceSha256=PIN
 return SAO.Needs.queueVerified(act)
end
local function current(a)
 local owner=provider(a.ownerName)
 for _,offer in ipairs(owner.intentOffers(a.id,a.body)or{})do
  local good=true
  for _,key in ipairs({'id','activity','sourceId','revision','itemKey','objectKey','pairObjectKey'})do if offer[key]~=a.offer[key]then good=false end end
  if good then return offer end
 end
end
local function advance(a)
 local stamp=now()
 if not stamp or stamp<a.startedAtMs or stamp-a.startedAtMs>POSE_LIMIT_MS then S.interrupt(a.id,a.body,'native pose timeout or clock unavailable');return false end
 if not live(a)or not identities(a)or not current(a)then S.interrupt(a.id,a.body,'maintained source or owned furniture unavailable');return false end
 if a.route then
  if SAO.Locomotion.jobs[a.id]~=a.route then S.interrupt(a.id,a.body,'seating route replaced');return false end
  SAO.Locomotion.tick(a.id)
  if not a.route.done then return true end
  if a.route.result~='arrived' or math.abs(a.body:getX()-a.approach.x)>.3 or math.abs(a.body:getY()-a.approach.y)>.3 then S.interrupt(a.id,a.body,'native seating approach not arrived');return false end
  a.route=nil
 end
 if a.action then
  if a.stopped or a.error then S.interrupt(a.id,a.body,a.error or 'native rest stopped');return false end
  if ISTimedActionQueue.hasAction(a.action)then return true end
  if not a.performed or not a.completed then S.interrupt(a.id,a.body,'native rest completion unavailable');return false end
  -- Source forceComplete can precede animation. Actual pose remains mandatory.
  if not a.body:isSittingOnFurniture()or not a.body:getVariableBoolean('SitOnFurnitureStarted')then a.row.phase='awaiting-native-pose';return true end
 end
 if pianoReady(a)then
  local offer=current(a);finish(a,'completed','native piano seating observed')
  return false,{ownerName=a.ownerName,offer=plain(offer),purposeId=a.purposeId}
 end
 if a.body:isSittingOnFurniture()then
  if a.body:getSitOnFurnitureObject()~=a.seat then S.interrupt(a.id,a.body,'different furniture owns native pose');return false end
  a.body:faceThisObject(a.piano);a.row.phase='native-facing';return true
 end
 if a.action then return true end
 if math.abs(a.body:getX()-a.approach.x)>.2 or math.abs(a.body:getY()-a.approach.y)>.2 then
  local prior=SAO.Locomotion.jobs[a.id]
  if prior and not prior.done then S.interrupt(a.id,a.body,'another route owns movement');return false end
  if not SAO.Standing.mayAttemptBelieved(a.id,math.floor(a.approach.x),math.floor(a.approach.y),'standing')
   or not SAO.Locomotion.order(a.id,a.body,a.approach.x,a.approach.y,a.approach.z,false)then S.interrupt(a.id,a.body,'native seating approach unavailable');return false end
  a.route=SAO.Locomotion.jobs[a.id];a.row.phase='approaching';return a.route~=nil
 end
 if queue(a)then return true end
 S.interrupt(a.id,a.body,'native rest queue unavailable');return false
end
local function chooseSeat(id,body,piano)
 local P=SAO.Perception;local sq=piano:getSquare();local best
 for index,row in ipairs(P.leisureObjects(id,body)or{})do
  if index>96 then break end
  if row.actorId==id and row.concept=='seat' and row.source=='native-personal-visibility'then
   local seen,seat=observation(id,body,row.key);local ss=seat and seat:getSquare()
   if seen and ss and ss:getZ()==sq:getZ()and math.abs(ss:getX()-sq:getX())<=1 and math.abs(ss:getY()-sq:getY())<=1
    and not seat:isFurnitureOccupied(body)and SeatingManager.getInstance():getTilePositionCount(seat)>0 then
    if body:isSittingOnFurniture()and body:getSitOnFurnitureObject()==seat then return seen,seat,{x=body:getX(),y=body:getY(),z=body:getZ()}end
    for _,direction in ipairs({'N','S','W','E'})do for _,side in ipairs({'Front','Left','Right'})do
     local pos=Vector3f.new()
     if SeatingManager.getInstance():getAdjacentPosition(body,seat,direction,side,'sitonfurniture','SitOnFurniture'..side,pos)then
      local x,y,z=pos:x(),pos:y(),pos:z()
      if finite(x)and finite(y)and finite(z)and z==sq:getZ()and math.abs(math.floor(x)-sq:getX())<=1 and math.abs(math.floor(y)-sq:getY())<=1 then
       local distance=(x-body:getX())^2+(y-body:getY())^2
       if not best or distance<best.distance then best={row=seen,seat=seat,x=x,y=y,z=z,distance=distance}end
      end
     end
    end end
   end
  end
 end
 if best then return best.row,best.seat,{x=best.x,y=best.y,z=best.z}end
end
function S.begin(id,body,ownerName,offer,purposeId)
 local r=record(id)
 if not r or not provider(ownerName)or type(offer)~='table'or offer.instrumentType~='Piano'or runtime[id]or isClient()or isServer()
  or not SAO.Needs.ownsRecoveryBody(id,body)or not SAO.Needs.workAvailable(body)then return false end
 local a={id=id,body=body,record=r,ownerName=ownerName,offer=plain(offer),purposeId=purposeId,
  token=body:getModData().SAOExternalToken,bodyOwner=r.bodyOwner,ownerToken=r.bodyOwnerToken,startedAtMs=now()}
 if not a.startedAtMs then return false end
 local p,piano=observation(id,body,offer.objectKey);local q,pair=observation(id,body,offer.pairObjectKey)
 if not p or not q or p.spriteName~=offer.objectSpriteName or q.spriteName~=offer.pairSpriteName
  or not offer.objectObservation or not offer.pairObservation
  or p.runtimeInstance~=offer.objectObservation.runtimeInstance or q.runtimeInstance~=offer.pairObservation.runtimeInstance then return false end
 a.pianoRow=plain(p);a.pairRow=plain(q);a.piano=piano;a.pair=pair
 local ok,t,seat,approach=pcall(chooseSeat,id,body,piano)
 if not ok or not t then return false end
 a.seatRow=plain(t);a.seat=seat;a.approach=plain(approach)
 a.row={actorId=id,ownerName=ownerName,purposeId=purposeId,offer=plain(offer),bodyToken=a.token,
  bodyGenerationKnown=a.token~=nil,status='preparing',phase='selected',admittedAtHours=SAO.History.countyHours(),
  seatObservation=plain(t),pianoObservation=plain(p),pairObservation=plain(q),approach=plain(approach)}
 r.leisureSeating=a.row;runtime[id]=a
 local good,held,ready=pcall(advance,a)
 if not good then S.interrupt(id,body,'native seating unavailable');return false end
 return held or ready~=nil,ready
end
function S.advance(id,body)
 local a=runtime[id]
 if not a or a.body~=body then return false end
 local ok,held,ready=pcall(advance,a)
 if not ok then S.interrupt(id,body,'native seating unavailable');return false end
 return held,ready
end
function S.reset(reason)
 local ids={}for id in pairs(runtime)do ids[#ids+1]=id end
 for _,id in ipairs(ids)do S.interrupt(id,runtime[id].body,reason)end
end
return S
