require=function()end
getText=function(t)return t end;getRecipeDisplayName=function(t)return t end
isClient=function()return false end;isServer=function()return false end
ISLogSystem={logAction=function()end}
Events={OnTick={Add=function(fn)__tickCallback=fn;__registrations=(__registrations or 0)+1 end,Remove=function()end}}
HaloTextHelper={addGoodText=function()error('operator Halo escaped')end,addText=function()error('operator Halo escaped')end}
getSpecificPlayer=function()error('operator slots escaped')end
getPlayer=function()error('operator actor escaped')end
getGameTime=function()return {getMultiplier=function()return 1 end}end
getCell=function()return {getGridSquare=function()return __square end}end
SandboxVars={LevelForMediaXPCutoff=10}
Perks=setmetatable({},{__index=function(t,k)local p={getId=function()return k end};t[k]=p;return p end})
getGameFilesTextInput=function(path)
 local text=__sources['native:'..path:sub(11)];if not text then return nil end
 if __sourceDrift then text=text..'\n-- changed native source\n'end
 local cursor=1;return {readLine=function()
  if cursor>#text then return nil end;local ending=text:find('\n',cursor,true)
  local line=text:sub(cursor,ending and ending-1 or #text);cursor=ending and ending+1 or #text+1;return line
 end,close=function()end}
end
instanceof=function(o,kind)return type(o)=='table'and o.class==kind end
SAO={Identity={get=function(id)return __records[id]end},History={countyHours=function()return __hours end},
 Needs={ownsRecoveryBody=function(id,body)return __owned and id=='person'and body==__body end},
 ConceptKnowledge={infer=function(id)return {actorId=id,paths=__familiar and {{id='prior:music',status='expectation',evidenceIds={'private-music-prior'},basis='personally-supported'}}or {}}end},
 Perception={leisureObjects=function()return __objects end,resolveLeisureObject=function(id,body,key)return __visible and __object and key=='object:radio'and __object or nil end,
  leisureAudioSources=function()return {}end},
 ProceduralPlanning={admitHobbyWork=function(id,pid,seq,owner)
  assert(owner=='SAO.LeisureRadio');local w=SAO.LeisureRadio.work(id);return __admit and pid=='purpose'and w and w.sequence==seq
 end,hobbyAdmission=function(id,pid,wid)
  local w=SAO.LeisureRadio.work(id);return __admit and w and w.workId==wid and {ownerName='SAO.LeisureRadio',sequence=w.sequence}or nil
 end,consumeHobbyOutcome=function(id,seq,owner)
  assert(owner=='SAO.LeisureRadio');assert(SAO.LeisureRadio.outcome(id,seq));__consumed=__consumed+1;return true
 end},LeisureSkill={consume=function(id,body,owner,work,seq)
  assert(owner=='SAO.LeisureRadio')
  if __tamper then __records.person.leisureRadioSkillRequests[#__records.person.leisureRadioSkillRequests].amount=999999 end
  local r=SAO.LeisureRadio.skillRequest(id,work,seq)
  assert(r and r.nativeProgress.nativeEmissionSequence and r.nativeProgress.actionStarted)
  __requestAmount=r.amount;__xp[r.perkName]=(__xp[r.perkName]or 0)+r.amount;__requests=__requests+1;return true
 end}}
SAOJavaBridge={privateCarriedItems=function()return {size=function()return #__items end,get=function(_,n)return __items[n+1]end}end,
 registerNativeRadioWork=function(_,body,wid,device,key,countyAt)
  __registers=__registers+1;if not __registerAllowed then return false end
  __registered={body=body,workId=wid,device=device,sourceKey=key,countyAt=countyAt or __nativeHours,nativeAt=__nativeHours};__events={};return true
 end,unregisterNativeRadioWork=function(_,body,wid)
  if __registered and __registered.body==body and __registered.workId==wid then __registered=nil;__unregisters=__unregisters+1 end
 end,nativeRadioPlaybackEvents=function(_,body,wid,cursor)
  local out={}if __registered and __registered.body==body and __registered.workId==wid then
   for _,row in ipairs(__events)do if row.sequence>cursor then out[#out+1]=row end end
  end;return out
 end,nativeRadioPlaybackEventCurrent=function(_,body,wid,seq,device)
  return __eventCurrent and __registered and __registered.body==body and __registered.workId==wid and __registered.device==device
 end,tickNativeRadioWork=function(_,body,wid)
  if __registered and __registered.body==body and __registered.workId==wid then
   return {actorId='person',workId=wid,frameNo=__frame,nativeAdvanced=true}
  end
 end}
ISTimedActionQueue={add=function(action)
 if __queueRefusal then return end
 __queue[#__queue+1]=action
 action.action={getJobDelta=function()return __delta end,forceStop=function()action:stop()end}
end,hasAction=function(action)for _,a in ipairs(__queue)do if a==action then return true end end;return false end,
getTimedActionQueue=function()return {resetQueue=function()__queue={}end,onCompleted=function(_,action)
 for n,a in ipairs(__queue)do if a==action then table.remove(__queue,n);break end end
end}end}
function __fresh()
 if SAO.LeisureRadio then SAO.LeisureRadio.reset('fixture-reset')end
 __hours=10;__nativeHours=10;__owned=true;__familiar=true;__admit=true;__sourceDrift=false;__registerAllowed=true;__eventCurrent=true
 __registers=0;__unregisters=0;__registered=nil;__events={};__queue={};__queueRefusal=false;__delta=0;__consumed=0
 __requests=0;__xp={};__level=0;__known={};__recipes={};__frame=100;__tamper=false;__visible=true;__objects={};__object=nil
 __stats:set(CharacterStat.BOREDOM,40);__stats:set(CharacterStat.UNHAPPINESS,30);__stats:set(CharacterStat.STRESS,.3)
 __stats:set(CharacterStat.FATIGUE,.2);__stats:set(CharacterStat.ENDURANCE,.7);__stats:set(CharacterStat.PANIC,0)
 local md={SAOExternalToken='generation:1'}
 __square={class='IsoGridSquare',getX=function()return 10 end,getY=function()return 10 end,getZ=function()return 0 end,
  isOutside=function()return false end,getDeviceData=function()return __data end}
 __body={getModData=function()return md end,isDead=function()return __dead==true end,isAsleep=function()return __asleep==true end,
  isAiming=function()return false end,isSneaking=function()return false end,getPrimaryHandItem=function()return __equipped and __radio or nil end,
  getSecondaryHandItem=function()return nil end,getVehicle=function()return nil end,getStats=function()return __stats end,
  getXp=function()return {getXP=function(_,perk)return __xp[perk:getId()]or 0 end}end,getPerkLevel=function()return __level end,
  getPlayerNum=function()return 1 end,getX=function()return 10.5 end,getY=function()return 10.5 end,getZ=function()return 0 end,
  getSquare=function()return __square end,isKnownMediaLine=function(_,guid)return __known[guid]==true end,
  addKnownMediaLine=function(_,guid)__known[guid]=true end,learnRecipe=function(_,name)local fresh=not __recipes[name];__recipes[name]=true;return fresh end,
  getMoodles=function()return {Update=function()__moodleUpdates=(__moodleUpdates or 0)+1 end}end,
  getInventory=function()return {getItemWithID=function(_,id)if id==1 then return __radio end end}end,
  faceThisObject=function()__faced=true end,setIsFarming=function()end}
 __on=true;__power=.8;__volume=.6;__channel=88000;__mediaIndex=-1;__mediaPlaying=false;__hasMedia=false;__equipped=true
 __hasBattery=true;__batteryRemoved=0;__batteryInserted=0
 __dead=false;__asleep=false;__buttons=0;__inserted=0;__faced=false
 __mediaData={getIndex=function()return 4 end}
 __data={getIsBatteryPowered=function()return true end,getPower=function()return __power end,canBePoweredHere=function()return false end,
  getHasBattery=function()return __hasBattery end,getBattery=function()
   __hasBattery=false;__power=0;__batteryRemoved=__batteryRemoved+1
  end,addBattery=function(_,item)
   if __hasBattery then return end
   __hasBattery=true;__power=item:getCurrentUsesFloat();__batteryInserted=__batteryInserted+1
   for n,it in ipairs(__items)do if it==item then table.remove(__items,n);break end end
  end,
  getIsTurnedOn=function()return __on end,setIsTurnedOn=function(_,v)__on=v end,getDeviceVolume=function()return __volume end,
  getChannel=function()return __channel end,setChannel=function(_,v)__channel=v end,getMediaIndex=function()return __mediaIndex end,
  getMediaType=function()return 0 end,hasMedia=function()return __hasMedia end,getMediaData=function()return __hasMedia and __mediaData or nil end,
  isPlayingMedia=function()return __mediaPlaying end,StartPlayMedia=function()__mediaPlaying=true end,StopPlayMedia=function()__mediaPlaying=false end,
  isIsoDevice=function()return __object~=nil end,isVehicleDevice=function()return false end,getIsTelevision=function()return false end,
  getParent=function()return __object or __radio end,playSoundSend=function()__buttons=__buttons+1 end,stopOrTriggerSoundByName=function()end,
  addMediaItem=function(_,item)__hasMedia=true;__mediaIndex=item:getMediaData():getIndex();__inserted=__inserted+1 end,
  getDevicePresets=function()return {getPresets=function()return {size=function()return 1 end,get=function()return {getFrequency=function()return 98000 end}end}end}end}
 __radio={class='Radio',getID=function()return 1 end,getFullType=function()return 'Base.RadioRed' end,getDeviceData=function()return __data end,
  getMediaType=function()return -1 end,getMediaData=function()return nil end}
 __items={__radio};__records={person={id='person'}}
end
function __emit(codes,guid,changes)
 assert(__registered);local row={actorId='person',workId=__registered.workId,sourceKey=__registered.sourceKey,
  sequence=#__events+1,atHours=__registered.countyAt+(__nativeHours-__registered.nativeAt),engineAtHours=__nativeHours,
  text='actually heard host content',guid=guid or 'guid:line',codes=codes or 'BOR-1',
  channel=__channel,mediaIndex=__mediaIndex,x=-1,y=-1,z=-1,authority='native-emission-current-owned-receiver'}
 for k,v in pairs(changes or {})do row[k]=v end;__events[#__events+1]=row;return row
end
function __runActions()
 while #__queue>0 do local action=__queue[1];assert(action:isValid());__delta=0;action:start();action:update();__delta=1
  action:perform();action:complete()
 end
end
