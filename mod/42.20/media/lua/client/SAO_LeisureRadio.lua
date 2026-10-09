-- Native radio/media actions and content heard by the current owned receiver.
-- Source content, codes, GUIDs and effects come from native emission receipts.
SAO=SAO or {};SAO.LeisureRadio=SAO.LeisureRadio or {}
local R=SAO.LeisureRadio
if R.reset then R.reset("module-reload")end
local runtime={}
local sources={}
local OWNER="SAO.LeisureRadio"
local SOURCE="native:ISRadioInteractions"
local PINS={
 ["shared/RadioCom/ISRadioInteractions.lua"]={"8a581253a9fe1ada7ffd7b1dad619308b8431699e964ff666726487516ada634",1238143337,1089453410,354},
 ["shared/RadioCom/ISRadioAction.lua"]={"c8b5a6a07c849c85f6be70db4037128d347c9f5c6ab55df1e8b0b4aac3377045",1034572030,862278107,207},
 ["shared/TimedActions/ISDeviceBatteryAction.lua"]={"50abf64e07afc3864b15b27d511cadd90245c8ff404fd0a070d163e4fe672c3e",1310853212,1675383173,67},
 ["shared/TimedActions/ISDeviceMediaAction.lua"]={"b63d61d009e0ca98538f6a7db1bbb5faa8a180c7555dc5960da29fd76af900b9",1935204688,318406979,49},
}
local function finite(v)return type(v)=="number"and v==v and math.abs(v)<1000000000 end
local function copy(v,depth)
 depth=depth or 0;if type(v)=="string"or type(v)=="boolean"then return v end
 if type(v)=="number"then return finite(v)and v or nil end
 if type(v)~="table"or depth>=8 then return nil end
 local out={}for k,x in pairs(v)do if type(k)=="string"or type(k)=="number"then out[k]=copy(x,depth+1)end end;return out
end
local function same(a,b)
 if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function person(id)return SAO.Identity and SAO.Identity.get(id)end
local function hours()return SAO.History.countyHours()end
local function live(id,body)return body and person(id)and SAO.Needs.ownsRecoveryBody(id,body)==true
 and not body:isDead()and not body:isAsleep()end
local function sp()return not isClient()and not isServer()end
local function items(body)
 local list=SAOJavaBridge:privateCarriedItems(body);local out={}
 for n=0,list:size()-1 do out[#out+1]=list:get(n)end;return out
end
local function itemKey(it)return "item:"..tostring(it:getID())..":"..it:getFullType()end
local function resolveItem(body,key)for _,it in ipairs(items(body))do if itemKey(it)==key then return it end end end
local function concept(id)
 local K=SAO.ConceptKnowledge;if not K or not K.infer then return nil end
 for _,effect in ipairs({"recreation","relief-from-stress"})do
  local v=K.infer(id,"music",effect);local p=v and v.actorId==id and v.paths and v.paths[1]
  if p and p.status=="expectation"and type(p.evidenceIds)=="table"and #p.evidenceIds>0 then
   return {id=p.id,evidenceIds=copy(p.evidenceIds),basis=p.basis,expectedEffect=effect,modal=true}end
 end
end
local function measure(body)
 local out={};local stats=body:getStats()
 for _,name in ipairs({"BOREDOM","UNHAPPINESS","STRESS","FATIGUE","ENDURANCE","PANIC"})do
  local stat=CharacterStat[name];if stat then local v=stats:get(stat);if finite(v)then out[name]=v end end
 end;return out
end
local function sourceChunk(env,path)
 local pin=PINS[path];if not pin then error("native-source-not-audited:"..path)end
 local reader=getGameFilesTextInput("media/lua/"..path);if not reader then error("native-source-unavailable:"..path)end
 local lines,h1,h2,total={},0,0,0
 local ok,why=pcall(function()while true do
  local line=reader:readLine();if line==nil then break end;line=tostring(line);total=total+#line+1
  if total>1048576 then error("native-source-too-large")end;lines[#lines+1]=line
  for n=1,#line do local b=string.byte(line,n);h1=(h1*31+b)%2147483647;h2=(h2*131+b)%2147483647 end
  h1=(h1*31+10)%2147483647;h2=(h2*131+10)%2147483647
 end end);reader:close();if not ok then error(why)end
 if h1~=pin[2]or h2~=pin[3]or #lines~=pin[4]then error("native-source-revision-changed:"..path)end
 local text=table.concat(lines,"\n").."\n"
 if path=="shared/RadioCom/ISRadioInteractions.lua"then
  -- Exact constructor-local persistence binding; original callbacks stay intact.
  local changed,count=text:gsub("local cooldowns = {};","local cooldowns = __sourceCooldowns;",1)
  if count~=1 then error("native-cooldown-binding-seam-changed")end;text=changed
 end
 local fn,err=loadstring(text,"native-radio:"..path);if not fn then error(err)end
 setfenv(fn,env);return fn()
end
local function revision()return PINS["shared/RadioCom/ISRadioInteractions.lua"][1]end
local function resolve(id,body,offer)
 if offer.itemKey then
  local item=resolveItem(body,offer.itemKey)
  return item and item:getFullType()==offer.itemType and instanceof(item,"Radio")and item or nil
 elseif offer.objectKey then
  local object=SAO.Perception.resolveLeisureObject(id,body,offer.objectKey)
  return object and object:getObjectName()=="Radio"and object:getSpriteName()==offer.objectSpriteName and object or nil
 elseif offer.audioSourceKey then
  local target=SAO.Perception.resolveLeisureAudioSource(id,body,offer.audioSourceKey)
  return target and target.part or nil,target
 end
end
local function near(body,device,kind)
 if kind=="carried"then return body:getPrimaryHandItem()==device or body:getSecondaryHandItem()==device end
 if kind=="vehicle"then return body:getVehicle()==device:getVehicle()end
 local square=device:getSquare();return square and body:getZ()==square:getZ()
  and math.abs(body:getX()-(square:getX()+.5))<=1.5 and math.abs(body:getY()-(square:getY()+.5))<=1.5
end
local function power(data)
 if data:getIsBatteryPowered()then return data:getPower()>0 end
 return data:canBePoweredHere()
end
local function replacementBattery(body,data,kind)
 if kind=="vehicle"or not data:getIsBatteryPowered()or power(data)then return nil end
 for _,it in ipairs(items(body))do
  if it:getFullType()=="Base.Battery"and instanceof(it,"DrainableComboItem")then
   local charge=it:getCurrentUsesFloat()
   if finite(charge)and charge>0 then return it,charge end
  end
 end
end
local function devices(id,body)
 local out={}
 for _,it in ipairs(items(body))do if instanceof(it,"Radio")and it:getDeviceData()then
  out[#out+1]={device=it,kind="carried",key=itemKey(it),itemKey=itemKey(it),itemType=it:getFullType()}end end
 local P=SAO.Perception
 for _,row in ipairs(P and P.leisureObjects and P.leisureObjects(id,body)or {})do
  local object=P.resolveLeisureObject(id,body,row.key)
  if object and object:getObjectName()=="Radio"and object:getDeviceData()then
   out[#out+1]={device=object,kind="placed",key=row.key,objectKey=row.key,objectSpriteName=object:getSpriteName(),observation=copy(row)}end
 end
 for _,row in ipairs(P and P.leisureAudioSources and P.leisureAudioSources(id,body)or {})do
  if row.sourceKind=="vehicle"and row.partId=="Radio"then
   local target=P.resolveLeisureAudioSource(id,body,row.key)
   if target and target.part and target.part:getDeviceData()then
    out[#out+1]={device=target.part,kind="vehicle",key=row.key,audioSourceKey=row.key,observation=copy(row)}end
  end
 end;return out
end
local function candidates(id,body,intents)
 if not sp()then return {},"multiplayer-native-radio-unverified"end
 if not live(id,body)or body:isAiming()or body:isSneaking()then return {},"radio-body-unavailable"end
 local evidence=concept(id);if not evidence then return {},"radio-personal-concept-unavailable"end
 local out={};local token=body:getModData().SAOExternalToken
 for _,d in ipairs(devices(id,body))do
  local data=d.device:getDeviceData();local ready=near(body,d.device,d.kind)
  local battery,batteryCharge=replacementBattery(body,data,d.kind)
  if (power(data)or battery)and data:getDeviceVolume()>0 and (ready or intents or data:getIsTurnedOn())then
   local channels={data:getChannel()};local seen={[data:getChannel()]=true}
   if ready or intents then
    local presets=data:getDevicePresets()and data:getDevicePresets():getPresets()
    if presets then for n=0,math.min(presets:size(),7)-1 do
     local freq=presets:get(n):getFrequency();if finite(freq)and not seen[freq]then channels[#channels+1]=freq;seen[freq]=true end
    end end
   end
   local media={};if data:hasMedia()and data:getMediaData()then media[#media+1]={index=data:getMediaIndex(),existing=true}end
   if (ready or intents)and not data:hasMedia()and d.kind~="vehicle"then
    for _,it in ipairs(items(body))do
     if it:getMediaType()==data:getMediaType()and it:getMediaData()and #media<6 then
      media[#media+1]={index=it:getMediaData():getIndex(),itemKey=itemKey(it),itemType=it:getFullType()}end
    end
   end
   local function append(activity,channel,entry)
    if #out>=24 then return end
    local needsControl=battery~=nil or not data:getIsTurnedOn()or channel~=data:getChannel()
     or entry and (entry.itemKey~=nil or not data:isPlayingMedia())
    local requires=not ready and (d.kind=="carried"or needsControl)and {}
    if requires then
     if d.kind=="carried"then requires.equipPrimary=d.itemKey
     elseif d.kind=="placed"then local s=d.device:getSquare();requires.frontSquare=true
      requires.targetX=s:getX()+.5;requires.targetY=s:getY()+.5;requires.targetZ=s:getZ()
     else return end
    end
    if requires and not intents then return end
    local offer={id="radio:"..id..":"..d.key..":"..activity..":"..tostring(entry and entry.index or channel),actorId=id,
     family="music",sourceId=SOURCE,revision=revision(),activity=activity,itemKey=d.itemKey,itemType=d.itemType,
     objectKey=d.objectKey,objectSpriteName=d.objectSpriteName,audioSourceKey=d.audioSourceKey,sourceKey=d.key,
     sourceKind=d.kind,observation=d.observation,channel=channel,mediaIndex=entry and entry.index,
     mediaItemKey=entry and entry.itemKey,mediaItemType=entry and entry.itemType,isOn=data:getIsTurnedOn(),
     currentChannel=data:getChannel(),currentMediaIndex=data:getMediaIndex(),mediaPlaying=data:isPlayingMedia(),
     batteryItemKey=battery and itemKey(battery),batteryItemType=battery and battery:getFullType(),
     batteryCharge=batteryCharge,replaceBattery=battery and data:getHasBattery(),
     bodyToken=token,bodyGenerationKnown=type(token)=="string"and #token>0,evidence=copy(evidence),
     participationUnit="one-native-heard-line",requiresPreparation=requires,
     revisionAuthority="audited native source; actor-private original callbacks"}
    out[#out+1]=offer
   end
   for _,ch in ipairs(channels)do if not data:isPlayingMedia()then append("listen-native-radio",ch,nil)end end
   for _,entry in ipairs(media)do append("listen-native-media",data:getChannel(),entry)end
  end
 end;return out
end
function R.materialRequirementsForType(_,itemType)
 if not sp()or type(itemType)~="string"or not getScriptManager then return {}end
 local definition=getScriptManager():getItem(itemType);if not definition then return {}end
 local role=itemType=="Base.Battery"and"battery"or definition:getRecordedMediaCat()and"media"
 if not role then return {}end
 local out={}
 for _,activity in ipairs(role=="battery"and{"listen-native-radio","listen-native-media"}or{"listen-native-media"})do
  out[#out+1]={owner=OWNER,family="music",activity=activity,sourceId=SOURCE,revision=revision(),
   role="material",requirementId=activity..":"..role,itemType=itemType}
 end;return out
end
function R.materialRequirementAvailable(id,body,row)
 if not sp()or not live(id,body)or not concept(id)or type(row)~="table"then return false end
 local admitted=false
 for _,preview in ipairs(R.materialRequirementsForType(nil,row.itemType))do if same(preview,row)then admitted=true;break end end
 if not admitted then return false end
 local battery=row.itemType=="Base.Battery"
 local definition=getScriptManager():getItem(row.itemType)
 local category=definition and definition:getRecordedMediaCat()
 local mediaType=category and RecordedMedia and RecordedMedia.getMediaTypeForCategory(category)
 for _,d in ipairs(devices(id,body))do
  local data=d.device:getDeviceData()
  if data:getDeviceVolume()>0 then
   if battery and d.kind~="vehicle"and data:getIsBatteryPowered()and not power(data)
    and not replacementBattery(body,data,d.kind)then return true end
   if not battery and mediaType and mediaType>=0 and data:getMediaType()==mediaType and not data:hasMedia()then
    local carried=false
    for _,it in ipairs(items(body))do
     if it:getMediaType()==mediaType and it:getMediaData()then carried=true;break end
    end
    if not carried then return true end
   end
  end
 end;return false
end
function R.offers(id,body)return candidates(id,body,false)end
function R.intentOffers(id,body)return candidates(id,body,true)end
local function bound(id,a)
 local w=person(id)and person(id).leisureRadioWork
 if not (runtime[id]==a and w and w.status=="active"and w.sequence==a.sequence and live(id,a.body)
  and w.bodyToken==a.body:getModData().SAOExternalToken)then return false end
 for _,field in ipairs({"actorId","sequence","workId","purposeId","family","sourceId","revision","activity",
  "itemKey","itemType","bodyToken","bodyGenerationKnown","admittedAtHours"})do
  if w[field]~=a.binding[field]then return false end
 end;return true
end
local function valid(id,a)
 if not bound(id,a)then return false end
 local P=SAO.ProceduralPlanning;local w=person(id).leisureRadioWork
 local admission=P and P.hobbyAdmission and P.hobbyAdmission(id,w.purposeId,w.workId)
 if not admission or admission.ownerName~=OWNER or admission.sequence~=w.sequence then return false end
 local device=resolve(id,a.body,a.offer)
 if device~=a.device or device:getDeviceData()~=a.data then return false end
 if a.offer.sourceKind=="carried"and not near(a.body,device,"carried")then return false end
 if a.expectedChannel~=nil and a.data:getChannel()~=a.expectedChannel then return false end
 if a.expectedMediaIndex~=nil and a.data:getMediaIndex()~=a.expectedMediaIndex then return false end
 if a.mediaItem and not a.mediaAdmitted and resolveItem(a.body,a.offer.mediaItemKey)~=a.mediaItem then return false end
 if a.batteryItem and not a.batteryAdmitted then
  if resolveItem(a.body,a.offer.batteryItemKey)~=a.batteryItem
   or a.batteryItem:getCurrentUsesFloat()~=a.offer.batteryCharge
   or a.data:getHasBattery()~=a.expectedHasBattery then return false end
 end
 return true
end
local function finish(id,status,reason)
 local rec=person(id);local w=rec and rec.leisureRadioWork;if not w or w.status~="active"then return false end
 local a=runtime[id];if status=="completed"and (not a or not a.heard)then status,reason="interrupted","native-content-not-heard"end
 if a then
  w=copy(a.binding);w.nativeProgress=copy(a.progress);w.nativeNotes=copy(a.notes)
  w.lastMeasured=copy(a.lastMeasured);rec.leisureRadioWork=w
  a.retiring=true
  pcall(function()SAOJavaBridge:unregisterNativeRadioWork(a.body,w.workId)end)
  for _,action in ipairs(a.actions or {})do
   if ISTimedActionQueue.hasAction(action)and action.action then pcall(function()action.action:forceStop()end)end
  end
 end
 w.status=status;w.reason=reason;w.atHours=hours();w.after=a and live(id,a.body)and measure(a.body)or w.lastMeasured
 w.token=status=="completed"and "leisure:performed"or "leisure:interrupted"
 w.measurementAuthority="actual native emission/source interval; concurrent effects not isolated"
 rec.leisureRadioOutcomes=rec.leisureRadioOutcomes or {};rec.leisureRadioOutcomes[#rec.leisureRadioOutcomes+1]=copy(w)
 if #rec.leisureRadioOutcomes>32 then table.remove(rec.leisureRadioOutcomes,1)end
 runtime[id]=nil
 if SAO.ProceduralPlanning and SAO.ProceduralPlanning.consumeHobbyOutcome then SAO.ProceduralPlanning.consumeHobbyOutcome(id,w.sequence,OWNER)end
 return true
end
local function environment(id,body)
 local rec=person(id);rec.leisureRadioCooldowns=rec.leisureRadioCooldowns or {}
 local env=setmetatable({__sourceCooldowns=rec.leisureRadioCooldowns,ISRadioInteractions={},ISRadioAction={},ISDeviceMediaAction={},ISDeviceBatteryAction={}},{__index=_G})
 env._G=env;env.require=function(name)if name=="TimedActions/ISBaseTimedAction"then return ISBaseTimedAction end;error("unaudited-radio-require:"..name)end
 env.Events=setmetatable({},{__index=function()return {Add=function()end}end})
 env.getSpecificPlayer=function(index)return index==body:getPlayerNum()and body or nil end
 env.HaloTextHelper={getGoodColor=function()return {}end,getBadColor=function()return {}end,
  addGoodText=function(actor,text)
   local a=runtime[id];if actor~=body or not a or not valid(id,a)or not a.sourceCallback then error("unbound-native-radio-halo")end
   a.notes=a.notes or {};if #a.notes<16 then a.notes[#a.notes+1]={text=text,sourceId=SOURCE}end
  end}
 env.HaloTextHelper.addText=function(actor,text)return env.HaloTextHelper.addGoodText(actor,text)end
 env.HaloTextHelper.addTextWithArrow=function(actor,text)return env.HaloTextHelper.addGoodText(actor,text)end
 env.addXp=function(actor,perk,amount)
  local a=runtime[id];local w=rec.leisureRadioWork
  if actor~=body or not a or not valid(id,a)or a.sourceCallback~="update"or not a.emission
   or not finite(amount)or amount<=0 then error("unbound-native-radio-XP")end
  rec.leisureRadioSkillSequence=(rec.leisureRadioSkillSequence or 0)+1
  local request={actorId=id,workId=w.workId,purposeId=w.purposeId,workSequence=w.sequence,sequence=rec.leisureRadioSkillSequence,
   perkName=perk:getId(),amount=amount,atHours=hours(),sourceId=SOURCE,revision=w.revision,status="requested",
   nativeProgress={sourceCallback="update",sourceInvocationSequence=a.sourceInvocationSequence,actionStarted=true,
    jobDelta=0,nativeEmissionSequence=a.emission.sequence}}
  a.skillRequests[request.sequence]=copy(request)
  rec.leisureRadioSkillRequests=rec.leisureRadioSkillRequests or {};rec.leisureRadioSkillRequests[#rec.leisureRadioSkillRequests+1]=copy(request)
  if #rec.leisureRadioSkillRequests>64 then table.remove(rec.leisureRadioSkillRequests,1)end
  if SAO.LeisureSkill and SAO.LeisureSkill.consume then SAO.LeisureSkill.consume(id,body,OWNER,w.sequence,request.sequence)end
 end
 for _,path in ipairs({"shared/RadioCom/ISRadioInteractions.lua","shared/RadioCom/ISRadioAction.lua",
  "shared/TimedActions/ISDeviceBatteryAction.lua","shared/TimedActions/ISDeviceMediaAction.lua"})do sourceChunk(env,path)end
 env.interactions=env.ISRadioInteractions:getInstance();return env
end
local function bindAction(id,a,action,after)
 local start,update,perform,complete,stop=action.start,action.update,action.perform,action.complete,action.stop
 local started=false;local performed=false;local completed=false
 local function invoke(fn,self,post)
  local ok,result=pcall(function()local value;if fn then value=fn(self)end;if post then post()end;return value end)
  if not ok then R.interrupt(id,a.body,"native-radio-action-callback-failed:"..tostring(result));return false end
  return true,result
 end
 action.start=function(self)if not valid(id,a)then return R.interrupt(id,a.body,"radio-source-owner-lost")end
  started=true;invoke(start,self)end
 action.update=function(self)if not valid(id,a)then return R.interrupt(id,a.body,"radio-source-owner-lost")end
  invoke(update,self)end
 action.perform=function(self)
  if performed then return end
  if not started or not valid(id,a)or self:getJobDelta()<1 then return R.interrupt(id,a.body,"premature-radio-action")end
  performed=true;invoke(perform,self,action.mode and after or nil)
 end
 action.complete=function(self)
  if completed then return true end
  if not started or not valid(id,a)or self:getJobDelta()<1 then R.interrupt(id,a.body,"premature-radio-complete");return false end
  completed=true;local ok,result=invoke(complete,self,not action.mode and after or nil);return ok and result
 end
 action.stop=function(self)if stop then pcall(stop,self)end;if not a.retiring and bound(id,a)then finish(id,"interrupted","native-radio-action-stopped")end end
 a.actions[#a.actions+1]=action
end
function R.begin(id,body,offer,purposeId)
 if not sp()or type(purposeId)~="string"or #purposeId==0 then return false,"radio-purpose-unavailable"end
 if runtime[id]then return false,"radio-work-already-active"end
 local current;for _,row in ipairs(R.offers(id,body))do if same(row,offer)then current=row;break end end
 if not current then return false,"stale-or-foreign-radio-offer"end
 local rec=person(id);if rec.leisureRadioWork and rec.leisureRadioWork.status=="active"then finish(id,"interrupted","radio-runtime-owner-lost")end
 local device=resolve(id,body,current);if not device then return false,"radio-custody-lost"end
 local ok,env=pcall(environment,id,body);if not ok then return false,"radio-source-construction-failed:"..tostring(env)end
 rec.leisureRadioSequence=(rec.leisureRadioSequence or 0)+1
 local w={actorId=id,sequence=rec.leisureRadioSequence,workId="radio:"..id..":"..rec.leisureRadioSequence,purposeId=purposeId,
  family="music",sourceId=SOURCE,revision=current.revision,activity=current.activity,itemKey=current.itemKey,itemType=current.itemType,
  bodyToken=current.bodyToken,bodyGenerationKnown=current.bodyGenerationKnown,admittedAtHours=hours(),status="active",phase="prepared",
  nativeOwner="original ISRadioAction/ISDeviceMediaAction; native radio distribution; original ISRadioInteractions.checkPlayer",
  nativeProgress={delta=0,observedUpdates=0,heardLines=0},before=measure(body),evidence=copy(current.evidence),sourceOffer=copy(current),
  participationUnit=current.participationUnit,revisionAuthority=current.revisionAuthority}
 local a={body=body,offer=current,device=device,data=device:getDeviceData(),env=env,sequence=w.sequence,actions={},
  cursor=0,skillRequests={},sourceInvocationSequence=0,expectedMediaIndex=current.currentMediaIndex,binding=copy(w),progress=copy(w.nativeProgress)};runtime[id]=a;rec.leisureRadioWork=w
 local P=SAO.ProceduralPlanning
 if not P or not P.admitHobbyWork or not P.admitHobbyWork(id,purposeId,w.sequence,OWNER)then
  finish(id,"interrupted","radio-planner-admission-refused");return false,"radio-planner-admission-refused"end
 local registered=SAOJavaBridge:registerNativeRadioWork(body,w.workId,device,current.sourceKey,w.admittedAtHours)
 if not registered then finish(id,"interrupted","native-radio-receiver-refused");return false,"native-radio-receiver-refused"end
 sources[id]={body=body,bodyToken=current.bodyToken,env=env}
 local built,why=pcall(function()
  local function radio(mode,argument,after)
   local action=env.ISRadioAction:new(mode,body,device,argument)
   bindAction(id,a,action,after or function()end)
  end
  if current.batteryItemKey then
   local item=resolveItem(body,current.batteryItemKey)
   if not item or item:getFullType()~="Base.Battery"or not instanceof(item,"DrainableComboItem")
    or item:getCurrentUsesFloat()~=current.batteryCharge then error("radio-battery-custody-or-charge-lost")end
   a.batteryItem=item;a.expectedHasBattery=a.data:getHasBattery()
   local parameter=current.sourceKind=="carried"and device:getID()or device:getSquare()
   local function batteryAction(remove,after)
    local secondary;if not remove then secondary=item end
    local action=env.ISDeviceBatteryAction:new(body,remove,secondary,parameter)
    if action.deviceData~=a.data then error("native-battery-parameter-not-exact-device")end
    bindAction(id,a,action,after)
   end
   if a.expectedHasBattery then
    batteryAction(true,function()
     if a.data:getHasBattery()then error("native-empty-battery-removal-failed")end
     a.expectedHasBattery=false
     a.progress.nativeBatteryPreparation={removed=true,inserted=false,hasBattery=false,
      power=a.data:getPower(),atHours=hours(),sourceCallback="complete"}
    end)
   end
   batteryAction(false,function()
    if not a.data:getHasBattery()or not power(a.data)then error("native-battery-insertion-failed")end
    a.batteryAdmitted=true
    a.progress.nativeBatteryPreparation={removed=current.replaceBattery==true,inserted=true,
     hasBattery=a.data:getHasBattery(),power=a.data:getPower(),itemKey=current.batteryItemKey,
     atHours=hours(),sourceCallback="complete"}
   end)
  end
  if not a.data:getIsTurnedOn()then radio("ToggleOnOff",nil,function()if not a.data:getIsTurnedOn()then error("native-radio-power-not-on")end end)end
  if current.mediaItemKey then
   local item=resolveItem(body,current.mediaItemKey);if not item or item:getFullType()~=current.mediaItemType then error("radio-media-custody-lost")end
   a.mediaItem=item
   local parameter=current.sourceKind=="carried"and device:getID()or device:getSquare()
   local action=env.ISDeviceMediaAction:new(body,false,item,parameter)
   if action.deviceData~=a.data then error("native-media-parameter-not-exact-device")end
   bindAction(id,a,action,function()a.mediaAdmitted=true;a.expectedMediaIndex=current.mediaIndex end)
  end
  if current.activity=="listen-native-radio"and current.channel~=a.data:getChannel()then
   radio("SetChannel",current.channel,function()a.expectedChannel=current.channel end)
  else a.expectedChannel=current.channel end
  if current.activity=="listen-native-media"then
   if not current.mediaItemKey then a.expectedMediaIndex=current.mediaIndex end
   if not a.data:isPlayingMedia()then radio("TogglePlayMedia",nil,function()if not a.data:isPlayingMedia()then error("native-media-not-started")end end)end
  end
  for _,action in ipairs(a.actions)do ISTimedActionQueue.add(action);if not ISTimedActionQueue.hasAction(action)then error("native-radio-queue-refused")end end
 end)
 if not built then R.interrupt(id,body,"radio-action-admission-failed:"..tostring(why));return false,"radio-action-admission-failed"end
 a.started=true;w.phase="awaiting-native-content";return true,copy(w)
end
function R.work(id)
 local a=runtime[id];if not a or not bound(id,a)then return nil end
 local w=copy(person(id).leisureRadioWork);w.nativeProgress=copy(a.progress);return w
end
function R.advance(id,body)
 local rec=person(id);local w=rec and rec.leisureRadioWork;if not w or w.status~="active"then return false end
 local a=runtime[id];if not a or a.body~=body or not valid(id,a)then return R.interrupt(id,body,"native-radio-owner-or-custody-lost")end
 for _,action in ipairs(a.actions)do if ISTimedActionQueue.hasAction(action)then return true end end
 if (a.offer.activity=="listen-native-media")~=a.data:isPlayingMedia()then return R.interrupt(id,body,"native-radio-content-mode-changed")end
 if not a.data:getIsTurnedOn()or not power(a.data)or a.data:getDeviceVolume()<=0 then return R.interrupt(id,body,"native-radio-power-or-volume-lost")end
 local ok,why=pcall(function()
  local rows=SAOJavaBridge:nativeRadioPlaybackEvents(body,w.workId,a.cursor)
  for _,row in ipairs(rows or {})do
   if row.authority~="native-emission-current-owned-receiver"or row.actorId~=id or row.workId~=w.workId
    or row.sourceKey~=a.offer.sourceKey or not finite(row.sequence)or row.sequence%1~=0 or row.sequence<=a.cursor
    or not finite(row.atHours)or row.atHours<w.admittedAtHours or row.atHours>hours()
    or row.channel~=a.data:getChannel()or row.mediaIndex~=a.data:getMediaIndex()
    or not SAOJavaBridge:nativeRadioPlaybackEventCurrent(body,w.workId,row.sequence,a.device)
    or type(row.text)~="string"or #row.text>4096 or row.guid~=nil and (type(row.guid)~="string"or #row.guid>512)
    or row.codes~=nil and (type(row.codes)~="string"or #row.codes>4096)then error("foreign-or-stale-native-radio-emission")end
   a.cursor=row.sequence;a.emission=row;a.sourceCallback="update";a.sourceInvocationSequence=a.sourceInvocationSequence+1
   -- Exact native emission was heard by this receiver. No catalogue line access.
   a.env.interactions.checkPlayer(body,row.guid,row.codes,row.x,row.y,row.z,row.text,a.device)
   a.sourceCallback=nil;a.emission=nil;a.heard=true
   a.progress.heardLines=a.progress.heardLines+1;a.progress.delta=1
   a.progress.nativeEmission=copy(row);a.progress.sourceInvocationSequence=a.sourceInvocationSequence
   a.lastMeasured=measure(body);w.nativeProgress=copy(a.progress)
   return finish(id,"completed","one-native-content-line-heard")
  end
 end)
 a.sourceCallback=nil;a.emission=nil
 if not ok then return R.interrupt(id,body,"native-radio-source-failed:"..tostring(why))end
 return true
end
function R.skillRequest(id,workSequence,sequence)
 local a=runtime[id];if not a or not valid(id,a)or not a.emission or a.sequence~=workSequence then return nil end
 local row=a.skillRequests[sequence];return row and copy(row)or nil
end
function R.outcome(id,sequence)
 local rec=person(id);for _,row in ipairs(rec and rec.leisureRadioOutcomes or {})do if row.actorId==id and row.sequence==sequence then return copy(row)end end
end
function R.interrupt(id,body,reason)
 local a=runtime[id];if a and body and a.body~=body then return false end
 return finish(id,"interrupted",reason or "radio-interrupted")
end
function R.detach(id,body)return R.interrupt(id,body,"radio-body-detached")end
function R.reset(reason)
 local ids={}for id in pairs(runtime)do ids[#ids+1]=id end
 for _,id in ipairs(ids)do R.interrupt(id,runtime[id].body,reason or "radio-reset")end
 sources={}
end
function R.onNativeTick()
 for id,source in pairs(sources)do
  local body=source.body;local a=runtime[id]
  if not live(id,body)or body:getModData().SAOExternalToken~=source.bodyToken then sources[id]=nil
  elseif a and valid(id,a)then
   local w=person(id).leisureRadioWork
   local ok,tick=pcall(function()return SAOJavaBridge:tickNativeRadioWork(body,w.workId)end)
   if ok and tick and tick.actorId==id and tick.workId==w.workId and finite(tick.frameNo)
    and tick.frameNo~=a.lastSourceFrame then
    a.lastSourceFrame=tick.frameNo;source.env.interactions.OnTick()
    a.progress.observedUpdates=a.progress.observedUpdates+1
    a.progress.lastNativeFrame=tick.frameNo;a.progress.nativeAdvanced=tick.nativeAdvanced==true
    w.nativeProgress=copy(a.progress)
   end
  elseif not a then
   -- Called only by the actual game OnTick. Reload/unobserved gaps do not decay.
   source.env.interactions.OnTick()
  end
 end
end
if Events and Events.OnTick then
 if R.eventCallback and Events.OnTick.Remove then Events.OnTick.Remove(R.eventCallback)end
 R.eventCallback=function()R.onNativeTick()end;Events.OnTick.Add(R.eventCallback)
end
