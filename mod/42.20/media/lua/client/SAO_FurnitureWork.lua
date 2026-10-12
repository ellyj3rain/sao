-- Person-private relocation and ordinary recovery retain separate outcomes.
require "SAO_FurnitureRelocationAction"
SAO=SAO or {};SAO.FurnitureWork=SAO.FurnitureWork or {}
local F=SAO.FurnitureWork
if F.runtimeCount then F.reset("module-reload");return F end
local runtime={}
local function copy(v)
 if type(v)~="table" then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o
end
local function now()return SAO.History.countyHours()end
local function rec(id)return SAO.Identity.get(id)end
local function owner(id,body)
 local r=rec(id);local md=body and body:getModData()
 return r and not r.dead and not r.bodyOwner and not r.zaoTransferPending and not r.crossedTransferPending
  and body and not body:isDead() and body:isExistInTheWorld() and SAO.Body.get(id)==body
  and not (SAO.Body.foreign and SAO.Body.foreign[id]) and md and md.SAOPersonId==id
  and md.SAOExternalOwner==nil and md.SAOExternalToken==r.bodyOwnerToken and md.ZAOOwned~=true
  and SAO.Body.active and SAO.Body.active[id]==body and SAOJavaBridge:isShell(body)==true
end
local function key(x,y,z)return x..":"..y..":"..z end
local function observed(map,s)return map[key(s:getX(),s:getY(),s:getZ())]end
local function currentObject(fact)
 local square=getCell():getGridSquare(fact.x,fact.y,fact.z);if not square then return nil end
 local object=square:getObjects():get(fact.index)
 if not object or not object:getSprite() or object:getSprite():getName()~=fact.sprite
  or SAOJavaBridge:furnitureObjectIdentity(object)~=fact.identity then return nil end
 return object
end
local function facts(id,body)
 if not SAO.Perception.observeFurniture(id,body) then return nil end
 local view=SAO.Perception.furnitureFacts(id,body);if not view then return nil end
 local map={};for _,s in ipairs(view.squares)do map[key(s.x,s.y,s.z)]=s end
 return view,map
end
local function permitted(id,b,admission)
 for _,m in ipairs(b.members)do
  if not SAO.Standing.mayRelocateBelieved(id,m.square:getX(),m.square:getY(),admission)
   or not SAO.Standing.mayRelocateBelieved(id,m.target:getX(),m.target:getY(),admission) then return false end
 end
 return true
end
local function passage(id,option)
 return option and option.contact and option.retreat
  and SAO.Standing.mayAttemptBelieved(id,option.contact.x,option.contact.y,option.admission)
  and SAO.Standing.mayAttemptBelieved(id,option.retreat.x,option.retreat.y,option.admission)
end
local function bedEvidence(view,source)
 local seed
 for _,square in ipairs(view.squares)do for _,o in ipairs(square.objects)do
  if o.bed and o.recoverySource==source and o.gridWidth and o.gridHeight and o.gridX and o.gridY then
   seed={x=square.x-o.gridX,y=square.y-o.gridY,z=square.z,w=o.gridWidth,h=o.gridHeight};break end
 end;if seed then break end end
 if not seed or seed.w*seed.h>4 then return nil end
 local members={}
 for gx=0,seed.w-1 do for gy=0,seed.h-1 do
  local found
  for _,square in ipairs(view.squares)do if square.x==seed.x+gx and square.y==seed.y+gy and square.z==seed.z then
   for _,o in ipairs(square.objects)do if o.bed and o.gridWidth==seed.w and o.gridHeight==seed.h and o.gridX==gx and o.gridY==gy then
    if found then return nil end
    found={x=square.x,y=square.y,z=square.z,sprite=o.sprite,facing=o.facing,bedType=o.bedType,
     gridWidth=o.gridWidth,gridHeight=o.gridHeight,gridX=o.gridX,gridY=o.gridY}
   end end
  end end
  if not found then return nil end;members[#members+1]=found
 end end
 return members
end
local function sameBed(a,b)
 if type(a)~="table" or type(b)~="table" or #a~= #b or #a<1 then return false end
 for i,m in ipairs(a)do for _,k in ipairs({"x","y","z","sprite","facing","bedType","gridWidth","gridHeight","gridX","gridY"})do
  if m[k]~=b[i][k] then return false end
 end end
 return true
end
local function allObserved(map,b)
 for _,m in ipairs(b.members)do
  local a,d=observed(map,m.square),observed(map,m.target)
  if not a or not d or not a.floor or not d.floor then return false end
  local seen=false;for _,o in ipairs(a.objects)do if o.index==m.object:getObjectIndex()
   and o.sprite==m.sprite and o.identity==SAOJavaBridge:furnitureObjectIdentity(m.object) then seen=true end end
  if not seen then return false end
 end
 return true
end
function F.options(id,body,kind,admission)
 if not owner(id,body) or kind~="sleep" then return {} end
 local view,map=facts(id,body);if not view then return {} end
 local options,seen={},{ }
 for _,s in ipairs(view.squares)do for _,bed in ipairs(s.objects)do if bed.bed and type(bed.recoverySource)=="string" then
  for _,side in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
   local obstruction=map[key(s.x+side[1],s.y+side[2],s.z)]
   if obstruction and not obstruction.free and not obstruction.occupied then
    for _,obj in ipairs(obstruction.objects)do if obj.movable and not obj.bed then
     local source={x=obstruction.x,y=obstruction.y,z=obstruction.z,index=obj.index,sprite=obj.sprite,identity=obj.identity}
     local object=currentObject(source)
     for _,delta in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
      local target=map[key(source.x+delta[1],source.y+delta[2],source.z)]
      if target and target.floor and target.free and not target.occupied then
       local destination=getCell():getGridSquare(target.x,target.y,target.z)
       for _,mode in ipairs({"push","pull"})do
        local b=SAO.FurnitureRelocation.bind(body,object,destination,mode,false)
        if b and allObserved(map,b) and permitted(id,b,admission) then
         local contact,retreat
         for _,m in ipairs(b.members)do
          local cx=m.square:getX()+(mode=="push" and -1 or 1)*b.moveX
          local cy=m.square:getY()+(mode=="push" and -1 or 1)*b.moveY
          local c=map[key(cx,cy,b.z)];local r=mode=="pull" and map[key(cx+b.moveX,cy+b.moveY,b.z)] or c
          if c and r and c.free and r.free and not c.occupied and not r.occupied
           and passage(id,{contact=c,retreat=r,admission=admission}) then
           contact={x=c.x,y=c.y,z=c.z};retreat={x=r.x,y=r.y,z=r.z};break end
         end
         local k="furniture:"..source.identity..":"..target.x..":"..target.y..":"..mode
         local bedMembers=bedEvidence(view,bed.recoverySource)
         if contact and bedMembers and not seen[k] and #options<32 then seen[k]=true
          options[#options+1]={key=k,actorId=id,source=source,destination={x=target.x,y=target.y,z=target.z},
           contact=contact,retreat=retreat,mode=mode,geometry=SAO.FurnitureRelocation.plain(b),
           recoveryApproach={x=source.x,y=source.y,z=source.z},expectedBed={key=bed.recoverySource,x=s.x,y=s.y,z=s.z,members=bedMembers,persistentObjectIdentity=false},observationRevision=view.revision,observedAtHours=view.atHours,
           admission=admission or "standing",basis="personally-visible-obstructed-bed-approach",uncertainBenefit=true}
         end
        end
       end
      end
     end
    end end
   end
  end
 end end end
 return options
end
local function ledger(r)
 if r.furnitureRelocation==nil then r.furnitureRelocation={schema=1,nextWork=0,nextResult=0,results={},order={}} end
 local s=r.furnitureRelocation
 if type(s)~="table" or getmetatable(s) or s.schema~=1 or type(s.results)~="table" or type(s.order)~="table" or #s.order>32
  or type(s.nextWork)~="number" or s.nextWork%1~=0 or s.nextWork<0 or s.nextWork>=999999999
  or type(s.nextResult)~="number" or s.nextResult%1~=0 or s.nextResult<0 or s.nextResult>=999999999 then return nil end
 return s
end
function F.outcome(id,sequence)
 local r=rec(id);local s=r and r.furnitureRelocation;local v=s and s.results[tostring(sequence)]
 if not v or v.actorId~=id or v.sequence~=sequence or v.id~=id.."/furniture-result/"..sequence
  or v.nativeOwner~="SAO.FurnitureRelocation.commit" or type(v.geometry)~="table" or type(v.geometry.members)~="table"
  or #v.geometry.members<1 or #v.geometry.members>64 then return nil end
 return copy(v)
end
local function result(id,work,ok,reason,changed)
 local r=rec(id);local s=r and ledger(r)
 if not s or r.furnitureWork~=work or work.resultSequence then return false end
 s.nextResult=s.nextResult+1;work.resultSequence=s.nextResult;work.status=ok and "completed" or "interrupted"
 local v={id=id.."/furniture-result/"..s.nextResult,sequence=s.nextResult,actorId=id,workId=work.id,purposeId=work.purposeId,
  kind="furniture-relocation",nativeOwner="SAO.FurnitureRelocation.commit",status=work.status,
  sourceId=work.option.key,atHours=now(),startedAt=work.startedAt,nativeCompleted=ok==true,nativeChanged=changed==true,nativeAttempted=work.nativeAttempted==true,
  geometry=copy(work.option.geometry),expectedBed=copy(work.option.expectedBed),reason=tostring(reason):sub(1,160),
  recoveredNativeMembers=copy(work.recoveredNativeMembers or {})}
 s.results[tostring(s.nextResult)]=v;s.order[#s.order+1]=s.nextResult
 if #s.order>32 then s.results[tostring(table.remove(s.order,1))]=nil end
 if SAO.ProceduralPlanning.consumeFurnitureResult then v.planningAcknowledged=SAO.ProceduralPlanning.consumeFurnitureResult(id,s.nextResult)==true end
 if SAO.Cognition.furnitureOutcome then v.learningAcknowledged=SAO.Cognition.furnitureOutcome(id,copy(v))==true end
 return true
end
local function validation(id,body,work,session)
 local p,step=SAO.ProceduralPlanning.furniturePurpose(id)
 return owner(id,body) and rec(id).furnitureWork==work and p and p.id==work.purposeId
  and p.admission and p.admission.correlationId==work.id and step and step.owner=="SAO.FurnitureWork"
  and work.status~="completed" and work.status~="interrupted" and passage(id,work.option) and permitted(id,session.binding,work.option.admission)
end
function F.begin(id,body,purpose,option)
 local r=rec(id);local s=r and ledger(r)
 if not owner(id,body) or not s or runtime[id] or not purpose or purpose.admission
  or not SAO.Needs.ownsRecoveryBody(id,body) or not SAO.Needs.workAvailable(body) then return false end
 local p,step=SAO.ProceduralPlanning.furniturePurpose(id)
 if p~=purpose or not step or step.owner~="SAO.FurnitureWork" or step.target~=option.key then return false end
 local view,map=facts(id,body);local object=currentObject(option.source)
 local destination=getCell():getGridSquare(option.destination.x,option.destination.y,option.destination.z)
 local session=SAO.FurnitureRelocationAction.session(body,object,destination,option.mode)
 if not session or not view or not passage(id,option) or not allObserved(map,session.binding) or not permitted(id,session.binding,option.admission) then return false end
 s.nextWork=s.nextWork+1
 local w={id=id.."/furniture-work/"..s.nextWork,actorId=id,purposeId=p.id,option=copy(option),startedAt=now(),status="approaching"}
 session.validate=function(v)return validation(id,body,w,v)end
 session.onResult=function(v,ok,reason,changed)w.nativeAttempted=v.binding.spent==true;w.recoveredNativeMembers=copy(v.binding.recovered or {});result(id,w,ok,reason,changed)end
 session.onRetreat=function(v)w.status="retreating"end
 r.furnitureWork=w;runtime[id]={body=body,session=session,work=w,phase="approach"}
 if not SAO.ProceduralPlanning.noteAdmission(id,p.id,"SAO.FurnitureWork",w.id,step.id) then runtime[id]=nil;r.furnitureWork=nil;return false end
 return true
end
local function reached(body,at)
 local s=body:getCurrentSquare()
 return s and s:getX()==at.x and s:getY()==at.y and s:getZ()==at.z and math.abs(body:getX()-(at.x+.5))<.45 and math.abs(body:getY()-(at.y+.5))<.45
end
local function walk(id,body,at,owned)
 local job=SAO.Locomotion.jobs[id]
 if job and not job.done and (job~=owned or job.body~=body or not job.goal or job.goal.x~=at.x or job.goal.y~=at.y or job.goal.z~=at.z) then return false end
 if not job or job.done then
  if not SAO.Locomotion.order(id,body,at.x,at.y,at.z,false) then return false end
  return true,SAO.Locomotion.jobs[id]
 end
 return true,job
end
function F.tick(id,body)
 local rt=runtime[id];if not rt then return false end
 if rt.phase=="return" then return F.tickReturn(id,body,rt) end
 if rt.body~=body or not SAO.FurnitureRelocationAction.validSession(rt.session) then F.interrupt(id,body,"body-purpose-or-geometry-changed");return false end
 local w,s=rt.work,rt.session
 if w.resultSequence then runtime[id]=nil;return false end
 local at=rt.phase=="approach" and w.option.contact or w.option.retreat
 if rt.phase=="approach" or rt.phase=="retreat" then
  if not reached(body,at) then
   local ok,job=walk(id,body,at,rt.job);rt.job=job
   if not ok then F.interrupt(id,body,"exact-route-refused") end
   return true
  end
  local job=SAO.Locomotion.jobs[id];if job and not job.done then return true end
  if SAOJavaBridge:hasPendingActions(body) then return true end
  if rt.phase=="retreat" and not SAO.FurnitureRelocationAction.commitRetreat(s) then F.interrupt(id,body,"retreat-not-admitted");return false end
  local a=SAO.FurnitureRelocationAction:new(s,rt.phase=="approach" and "effort" or "commit")
  if not a or not SAO.Needs.queueVerified(a) then F.interrupt(id,body,"native-queue-refused");return false end
  rt.action=a;rt.phase="action";w.status="effort"
 elseif s.phase=="retreat" then rt.phase="retreat";w.status="retreating" end
 return true
end
function F.interrupt(id,body,reason)
 local rt=runtime[id];if not rt then return true end
 if rt.session then SAO.FurnitureRelocationAction.cancel(rt.session,reason) end
 local job=SAO.Locomotion.jobs[id]
 if job and job==rt.job and job.body==rt.body then SAO.Locomotion.cancel(id) end
 if rt.phase=="return" and rec(id) and rec(id).furnitureReturn then rec(id).furnitureReturn.status="interrupted" end
 runtime[id]=nil;return true
end
function F.reconcile(id,body)
 local r=rec(id);local w=r and r.furnitureWork
 if w and not runtime[id] and not w.resultSequence then
  result(id,w,false,"saved-native-work-is-unobserved",false)
 end
 local s=r and r.furnitureRelocation
 for _,sequence in ipairs(s and s.order or {})do local row=s.results[tostring(sequence)]
  if row and not row.planningAcknowledged then row.planningAcknowledged=SAO.ProceduralPlanning.consumeFurnitureResult(id,sequence)==true end
  if row and not row.learningAcknowledged then row.learningAcknowledged=SAO.Cognition.furnitureOutcome(id,F.outcome(id,sequence))==true end
 end
 for _,sequence in ipairs(s and s.useOrder or {})do local row=s.useResults[tostring(sequence)]
  if row and not row.learningAcknowledged then row.learningAcknowledged=SAO.Cognition.furnitureUseOutcome(id,F.useOutcome(id,sequence))==true end
 end
 return true
end
function F.active(id,body)F.reconcile(id,body);return runtime[id] and runtime[id].body==body or false end
function F.forget(id)F.interrupt(id,nil,"owner-retired");runtime[id]=nil end
function F.runtimeCount()local n=0;for _ in pairs(runtime)do n=n+1 end;return n end
function F.reset(reason)local ids={};for id in pairs(runtime)do ids[#ids+1]=id end;for _,id in ipairs(ids)do F.interrupt(id,nil,reason)end end
function F.useOutcome(id,sequence)
 local r=rec(id);local s=r and r.furnitureRelocation;local c=s and s.useResults and s.useResults[tostring(sequence)]
 return c and c.actorId==id and c.sequence==sequence and copy(c) or nil
end
function F.consumeUse(id,origin,sequence)
 local r=rec(id);local s=r and ledger(r);local p=SAO.ProceduralPlanning.furniturePurpose(id);local f=p and p.furnitureRelocation
 local c=origin=="means" and SAO.Needs.meansResult(id,sequence) or origin=="recovery" and SAO.Needs.behaviorOutcome(id,sequence)
 if not s or not f or f.recoveryBindingUnavailable or not f.resultId or not c or c.actorId~=id or c.sourceId~=f.expectedBed.key then return false end
 local physical
 for _,n in ipairs(s.order)do local v=s.results[tostring(n)];if v and v.id==f.resultId then physical=v end end
 if not physical or physical.status~="completed" or not physical.nativeCompleted or c.atHours<physical.atHours or c.atHours>now() then return false end
 if origin=="means" and (sequence<=(f.meansSequenceBefore or 0) or c.owner~="SAO.Needs" or c.available~=false
  or c.scope~="geometry" and c.scope~="admission" and c.scope~="approach") then return false end
 if origin=="recovery" and (not p.admission or p.admission.owner~="SAONeeds" or sequence<=(f.recoverySequenceBefore or 0)
  or c.actionKind~=f.kind or not c.durationHours or c.durationHours<=0) then return false end
 s.useResults=s.useResults or {};s.useOrder=s.useOrder or {};s.seenUse=s.seenUse or {};s.nextUse=s.nextUse or 0
 s.useSequenceFloor=s.useSequenceFloor or {}
 local receiptKey=origin..":"..sequence
 if s.seenUse[receiptKey] or sequence<=(s.useSequenceFloor[origin] or 0) then return true end
 s.useSequenceFloor[origin]=sequence
 s.nextUse=s.nextUse+1
 local u={id=id.."/furniture-use/"..s.nextUse,sequence=s.nextUse,actorId=id,purposeId=p.id,
  relocationResultId=physical.id,sourceId=physical.sourceId,consumerId=c.sourceId,ownerSequence=sequence,origin=origin,
  nativeOwner=origin=="means" and "SAO.Needs.meansResult" or "SAO.Needs.behaviorOutcome",
  actionKind=origin=="means" and c.scope or c.actionKind,succeeded=origin=="recovery" and c.succeeded==true or false,atHours=c.atHours}
 s.useResults[tostring(u.sequence)]=u;s.useOrder[#s.useOrder+1]=u.sequence;s.seenUse[receiptKey]=u.sequence
 if #s.useOrder>32 then local old=s.useResults[tostring(table.remove(s.useOrder,1))]
  s.useResults[tostring(old.sequence)]=nil;s.seenUse[old.origin..":"..old.ownerSequence]=nil end
 u.learningAcknowledged=SAO.Cognition.furnitureUseOutcome(id,copy(u))==true
 return true
end

-- Reacquisition relates the saved appearance/footprint to a currently eligible
-- native source; the former pointer-derived key remains historical provenance.
function F.rebindRecovery(id,body,places)
 local p,step=SAO.ProceduralPlanning.furniturePurpose(id);local f=p and p.furnitureRelocation
 if not owner(id,body) or not f or not f.resultId or p.admission or not step or step.owner~="SAONeeds" then return false end
 local view=facts(id,body);local expected=f.expectedBed
 if not view or not expected or type(expected.members)~="table" then f.recoveryBindingUnavailable=true;return false end
 for _,place in ipairs(SAO.Needs.recoveryPlaces(id,body))do if place.kind=="bed" and place.available==true then
  local members=bedEvidence(view,place.key);local allowed=SAO.Standing.mayAttemptBelieved(id,place.x,place.y,f.option.admission)
  for _,m in ipairs(members or {})do if not SAO.Standing.mayAttemptBelieved(id,m.x,m.y,f.option.admission) then allowed=false end end
  if allowed and sameBed(expected.members,members) then
   if expected.key~=place.key then
    f.originalBedKey=f.originalBedKey or expected.key;f.bedBindings=f.bedBindings or {}
    f.bedBindings[#f.bedBindings+1]={actorId=id,previousKey=expected.key,currentKey=place.key,originalKey=f.originalBedKey,
     atHours=view.atHours,revision=view.revision,physicalResultId=f.resultId,persistentObjectIdentity=false}
    if #f.bedBindings>8 then table.remove(f.bedBindings,1) end
    expected.key=place.key
   end
   expected.persistentObjectIdentity=false;f.recoveryBindingUnavailable=false;return true
  end
 end end
 f.recoveryBindingUnavailable=true;return false
end

function F.returnForRecovery(id,body,purpose)
 local p,step=SAO.ProceduralPlanning.furniturePurpose(id);local f=p and p.furnitureRelocation
 if not owner(id,body) or p~=purpose or not f or not f.resultId or p.admission or not step or step.owner~="SAONeeds"
  or f.recoveryBindingUnavailable or f.returnedAtHours or runtime[id] or not f.option.recoveryApproach then return false end
 local target=f.option.recoveryApproach
 if not SAO.Standing.mayAttemptBelieved(id,target.x,target.y,f.option.admission) then return false end
 runtime[id]={body=body,phase="return",purposeId=p.id,resultId=f.resultId,target=copy(target)}
 rec(id).furnitureReturn={purposeId=p.id,resultId=f.resultId,target=copy(target),status="approaching",startedAtHours=now()}
 return true
end
function F.tickReturn(id,body,rt)
 local p,step=SAO.ProceduralPlanning.furniturePurpose(id);local f=p and p.furnitureRelocation
 if not owner(id,body) or rt.body~=body or not p or p.id~=rt.purposeId or not f or f.resultId~=rt.resultId
  or f.recoveryBindingUnavailable or p.admission or not step or step.owner~="SAONeeds" or not SAO.Standing.mayAttemptBelieved(id,rt.target.x,rt.target.y,f.option.admission) then
  F.interrupt(id,body,"return-purpose-or-standing-changed");return false
 end
 if reached(body,rt.target) and (not rt.job or rt.job.done) then
  f.returnedAtHours=now();rec(id).furnitureReturn.status="returned";runtime[id]=nil
  return false
 end
 local ok,job=walk(id,body,rt.target,rt.job)
 if not ok then F.interrupt(id,body,"return-route-refused");return false end
 rt.job=job;return true
end

return F
