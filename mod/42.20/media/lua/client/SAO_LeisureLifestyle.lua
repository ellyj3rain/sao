-- Original installed Lifestyle physical music families, scoped to acquired
-- sources and canonical private purposes. Source license/attribution retained.
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
SAO=SAO or {}
if not SAO.SourceIntegration and type(require)=="function"then pcall(require,"SAO_SourceIntegration")end;SAO.LeisureLifestyle=SAO.LeisureLifestyle or {}
local L=SAO.LeisureLifestyle
if L.reset then L.reset("module-reload")end
if L._originalDJGuard and L._originalDJGuard.restore then L._originalDJGuard.restore()end
local OWNER,SOURCE="SAO.LeisureLifestyle","LifestyleHobbies"
local runtime,physicalOwners,ownedDJActions={},{},{}
local djGuard={active=true}
L._originalDJGuard=djGuard
local externalBridge=L._externalPhysicalBridge or {menus={},originalMenus={}}
local menuCallbacks={"onPlay","onTurnOnOff","onTurnOn","onTurnOff"}
externalBridge.generation=(externalBridge.generation or 0)+1
externalBridge.ready=false
L._externalPhysicalBridge=externalBridge
local ensureExternalBridge
local djOwned,installOriginalDJGuard,djGuardReady
local PINS={
 ["client/XpSystem/PlayerTracker.lua"]={"3b78755a7fb00e44bcdd0058fcd2b7cfe9e05b8bdbaf629e40ec7b0df92fca52",1922440540,1884050285,228},
 ["client/LSEffects/LSCreation.lua"]={"949579f1a250d98fa24506d8ce0925714707b26fbd2c5262d23d73d28f347c82",144090041,198892203,348},
 ["client/LSEffects/LSPerMinute.lua"]={"fb4a5ea5f617554bfd88e8340ee35ae4a42eb299f4f39eb64d61bf53c23d9afd",439614848,998313515,785},
 ["client/LSMoodleManager.lua"]={"7fd07315ac820143f47db01ac8f3c4fc8f5f7b80241ddb4da47c69a362ac8eee",702292896,1790240309,679},
 ["client/Properties/MoodleProperties.lua"]={"092a1418bc9f5b48e692ccaaeb8cd1d43f324047891cbf11b18978fcc9aea919",887135936,767826158,50},
 ["client/LSEffectsAux.lua"]={"e74b674c4ebe7f2dcfd6468f3c491bcbf4b7e133ded3fdbb5757c9011443012e",492680856,1905846185,325},
 ["client/InteractionRange.lua"]={"784527f5aee1c38b5c436daf0316777742177c7a5f5d91bfb9be180878b58f9d",861431604,2012873013,319},
 ["shared/LSUtil.lua"]={"4e6b73720eefcafd828773067327664aa854228a6080705cf948c9cecc149ddb",1541193869,1686604880,2388},
 ["shared/TimedActions/JukeboxOn.lua"]={"9cc59ec2b6e3d55816548e9dd836aa86e3b4cb0865e06734b6fbd353fe01e238",2047060807,2141009942,130},
 ["shared/TimedActions/JukeboxPlay.lua"]={"fc1848497c41fa26b8374e88c26ea77bd7e2db4c9ff68099b4d65a645a7152c6",476168971,854071125,139},
 ["shared/TimedActions/JukeboxOff.lua"]={"1bfdc40c5c88427b5167a5fe6bf3ec143cb3d4b21fa28fb584981a6495585c16",1910846605,577149947,121},
 ["shared/TimedActions/PlayDJBoothAction.lua"]={"6a8d3dd5767260e67ea96353a197ce577a3a023ccc7e2fd56151a2a8f55e7dac",436066307,1302486810,792},
 ["shared/Attributes/DjBooth_defs.lua"]={"755763e214330d25942c91418b577f9d5790bc826584e2d9e731e8fcb70e91bc",1707792591,674154144,65},
 ["client/TimedActions/PlayDJBoothTracks.lua"]={"d1105e903a46d49942a00e7db1ce55c8e6ffd83126c1e28742c9ba707e3ab0c4",333350521,611988881,38},
 ["client/DJBoothBind.lua"]={"c0572367217db6ab2672efacd2a803908e602a9cbb17698b9e0259b16a0e988f",453405142,313799163,56},
 ["client/DJBoothContextMenu.lua"]={"8894fd69dcf5326dfd740d36b26c4fc95f2b1f7c01fdd6dd3e2b54e45256fa93",1604758143,1940570876,477},
 ["client/LSIsListeningEffects.lua"]={"44a2a0490c84d256b8a10023f9b08032f8a488bcce9d6ccb89dd8843d8fbfe12",624071614,1622846682,216},
 ["client/ZLSUpdate.lua"]={"c58b35124994912441577e6fa66c704adec5a5844193290b1392662c9ee27d2b",1277481242,1314231177,228},
 ["client/LSEffects.lua"]={"e074ba9fec56a290a8ea6860f330aa2fb6f05f291b6ce21282636bcf22d03a47",482720023,1339801030,147},
 ["client/LSEffectsJukeboxFunctions.lua"]={"df74d56767ec977487c0e916c32846afd8f0285fa15d476278aaedf441ecf49f",336938400,1771124984,325},
 ["client/DiscoStateChange.lua"]={"5b34989c686e9a1c4f80dd575537bf35506d659a2a4455e83a9df97b16d54bca",1379593987,1481398932,296},
 ["client/Properties/Objects/Handler.lua"]={"7784c5c61d278dfb5b1a49899e3ba777813f6cfd13bc013006de6385fd5efaaf",1787381548,1345664657,170},
 ["shared/TimedActions/ToneDeafSuffering.lua"]={"d5607e1a00d3b779d0e09200b2ebc76fffdab21d0ced52021c4cb030ec56a841",1513159884,145249498,127},
 ["shared/TimedActions/BooingMusician.lua"]={"73ccd34235b0c82c9821af2bfeec260a0f668324de33c349f9b86f77185f27b8",1884730094,458799333,129},
 ["shared/TimedActions/PraiseMusician.lua"]={"794ad085355a32314d2fb010a8875ea488a04a18b3bf9bb2475cd4df9d69c502",615283045,687799354,129},
 ["client/TimedActions/PlayerVoiceTracks.lua"]={"4b5dd1871c51b68514922f804d2c10d4fe6775f72532c0c3e376a0a0bc3c732c",1647777782,736065194,145},
 ["client/JukeboxTracks/Beach.lua"]={"e37cdf952b11cd32d09e97b60c4a2d2c6d2958005a8706c088eed64e45181dec",1584517128,1806118886,36},
 ["client/JukeboxTracks/Classical.lua"]={"0964c322188fa3d269d16f68d5667c41783f82eba102c29e9fafdb1a14acfeb3",1011896730,2012156568,31},
 ["client/JukeboxTracks/Country.lua"]={"656978058e463a6eae8bdf4f6161f46b449a3a49d91b5465624c0023a914d549",1222472744,905052692,36},
 ["client/JukeboxTracks/Disco.lua"]={"7ae1d8a7e97564f99469ce80a346541c9035ad8ec009a7432fa790fd6c169908",787433920,74504435,30},
 ["client/JukeboxTracks/Holiday.lua"]={"77b46fee625111dc39cbf69b684a5099f1090d743b900e9352f6aa3f852bea59",629324066,844147266,25},
 ["client/JukeboxTracks/Jazz.lua"]={"f5a4ff472fb68c078473d120b60daf0d50869945f33808eb388c48c0dfbb4e65",1587594005,644116878,47},
 ["client/JukeboxTracks/Metal.lua"]={"70a998787d885a156c4cbdd5246d0ec1c5272d218e54b5c528e5d58fe51502fc",1791715713,108707601,28},
 ["client/JukeboxTracks/Muzak.lua"]={"2b3ba342b2541c49d4627916770432dfef68611cc5a38c2af6e2284ec5b1242f",1418836624,722991615,25},
 ["client/JukeboxTracks/Pop.lua"]={"8da942689cb0f7a10bb2fa445fc29d43dfde4d8d60a1d68c81baf91e2a63551c",1816001184,1036195583,89},
 ["client/JukeboxTracks/Rap.lua"]={"061ffb229582a5edea1a5d04fb9645d0ccf1dc4155c016b5b2865dd23091e198",1191073169,2118166930,34},
 ["client/JukeboxTracks/RB.lua"]={"9b50b278a5dd888ff57f2003be78eca8c847844350308d4228b06bfa00c6f207",2137007772,917516577,30},
 ["client/JukeboxTracks/Reggae.lua"]={"1f261f29904c8601cbde34fc11b0ce34e163244dd0ab8525db67812a04d1e634",1258950536,1526237745,24},
 ["client/JukeboxTracks/Rock.lua"]={"fc5cf1dec410edacb642df7f5210fabe8af56aec3907c5d20bcd0490b2967a1a",1535789830,1666446080,50},
 ["client/JukeboxTracks/Salsa.lua"]={"d6a1e9f890d3e76441cbe2301af26a988ce6cc5821ba69bdd649d10eee8fae8f",1806399671,1971086317,34},
 ["client/JukeboxTracks/World.lua"]={"5e34ca83a828ba535bd1afd7884a96f781399c400c3878fcd85d4bbd72c96ca1",239990957,1613472967,44},
}
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end
local function plain(v,depth)
 depth=depth or 0;if type(v)=="string"or type(v)=="boolean"then return v end
 if type(v)=="number"then return finite(v)and v or nil end
 if type(v)~="table"or depth>8 then return nil end
 local r={};for k,x in pairs(v)do if type(k)=="string"or type(k)=="number"then r[k]=plain(x,depth+1)end end;return r
end
local function same(a,b)
 if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function rec(id)return SAO.Identity and SAO.Identity.get(id)end
local function now()return SAO.History.countyHours()end
local function live(id,body)
 local r=rec(id);return r and not r.dead and body and not body:isDead()and not body:isAsleep()
  and body:isExistInTheWorld()and SAO.Needs.ownsRecoveryBody(id,body)==true
end
local function enabled()return (not isClient or not isClient())and(not isServer or not isServer())and SAO.SourceIntegration and SAO.SourceIntegration.available(SOURCE)==true end
local function externalSelected()
 return SAO.SourceIntegration and SAO.SourceIntegration.externalSelected
  and SAO.SourceIntegration.externalSelected(SOURCE)==true
end
local function stationPhysicalEnabled()
 if not enabled()then return false end
 if not externalSelected()then return SAO.SourceIntegration.active(SOURCE)==true end
 if not externalBridge.ready or _G.LSrefreshJB~=externalBridge.range
  or _G.JukeboxMusicCheck~=externalBridge.ending or JukeboxMenu~=externalBridge.menu then return false end
 for _,name in ipairs(menuCallbacks)do
  if (name=="onPlay"or name=="onTurnOnOff")and type(JukeboxMenu[name])~="function"then return false end
  if JukeboxMenu[name]~=externalBridge.menus[name]then return false end
 end
 return true
end
local function originalDJBusy()
 return type(LS_DJBooth)=="table"and(LS_DJBooth.isPlaying==true or LS_DJBooth.isPlayingMic==true)
end
local function playerDJQueued(object)
 if not object then return false end
 if DJBoothMenu and type(DJBoothMenu.playerQueueOwner)=="function"then
  local ok,owns=pcall(DJBoothMenu.playerQueueOwner,object)
  if not ok or owns==true then return true end
 end
 -- When the external Lifestyle copy is active, its original callback queues
 -- the same selected timed-action class but has no SAO menu claim. Read only
 -- native player queues, never an NPC shell or a similarly named station.
 local queues=ISTimedActionQueue and ISTimedActionQueue.queues
 if type(queues)~="table"or type(getSpecificPlayer)~="function"then return false end
 for slot=0,3 do
  local ok,player=pcall(getSpecificPlayer,slot)
  local queue=ok and player and queues[player]
  for _,action in ipairs(queue and queue.queue or{})do
   if action.DJBooth==object and action.Type=="PlayDJBoothAction"then return true end
  end
 end
 return false
end
local function revision(path)return PINS[path]and PINS[path][1]end
local function chunk(env,path,adapt)
 local pin=PINS[path];if not pin then error("lifestyle-source-unpinned:"..path)end
 local reader=SAO.SourceIntegration and SAO.SourceIntegration.reader(SOURCE,"media/lua/"..path);if not reader then error("lifestyle-source-absent:"..path)end
 local lines,a,b={},0,0
 local ok,why=pcall(function()
  while true do local line=reader:readLine();if line==nil then break end;line=tostring(line)
   lines[#lines+1]=line;if #lines>12000 then error("source-too-large")end
   for n=1,#line do local c=string.byte(line,n);a=(a*31+c)%2147483647;b=(b*131+c)%2147483647 end
   a=(a*31+10)%2147483647;b=(b*131+10)%2147483647
  end
 end);reader:close();if not ok then error(why)end
 if a~=pin[2]or b~=pin[3]or #lines~=pin[4]then error("lifestyle-source-revision-changed:"..path)end
 local code=table.concat(lines,"\n").."\n";if adapt then code=adapt(code)end
 local fn,err=loadstring(code,SOURCE..":"..path);if not fn then error(err)end;setfenv(fn,env);return fn()
end
local function replaceSourceOnce(code,old,new)
 local at=assert(code:find(old,1,true),"lifestyle-global-callback-site-absent")
 if code:find(old,at+#old,true)then error("lifestyle-global-callback-site-ambiguous")end
 return code:sub(1,at-1)..new..code:sub(at+#old)
end
local function leased(object)
 return SAO.LeisureLifestyle and SAO.LeisureLifestyle.physicalSourceOwner
  and SAO.LeisureLifestyle.physicalSourceOwner(object)==true
end
local function guardRange(code)
 local prior="\t\t\t---\n\t\t\tif v:getModData().JukeinRange"
 local guarded="\t\t\t---\n\t\t\tif not (SAO.LeisureLifestyle and SAO.LeisureLifestyle.physicalSourceOwner and SAO.LeisureLifestyle.physicalSourceOwner(v) == true) then\n\t\t\tif v:getModData().JukeinRange"
 code=replaceSourceOnce(code,prior,guarded)
 local close="\t\t\tend--range\n\t\t\t\n\t\t\t------------------------------------"
 local playerRead="\t\t\tend--range\n\t\t\telse\n\t\t\t\tlocal readObject; readObject, Facing, groupName = getObj(v, \"Jukebox\")\n\t\t\t\tif Facing == \"S\" then JukeboxLightSprite, JukeboxLightSpritePlay1, JukeboxLightSpritePlay2, JukeboxLightSpritePlayOverlay = \"LS_JukeboxLight_4\", \"LS_JukeboxLight_5\", \"LS_JukeboxLight_6\", \"LS_JukeboxLight_7\" end\n\t\t\t\tif v:getModData().OnOff == \"on\" and v:getModData().OnPlay and v:getModData().OnPlay ~= \"nothing\" and v:getModData().genre ~= \"JukeboxAfterTurnOn\" and playerIsInRange(playerObj, v, 30) then hasJukeNearby = true end\n\t\t\tend--sao-physical-owner\n\t\t\t\n\t\t\t------------------------------------"
 return replaceSourceOnce(code,close,playerRead)
end
local function guardEnding(code)
 return replaceSourceOnce(code,"\t\t\t\t\tif v:hasModData() and\n\t\t\t\t\tv:getModData().OnOff",
  "\t\t\t\t\tif not (SAO.LeisureLifestyle and SAO.LeisureLifestyle.physicalSourceOwner and SAO.LeisureLifestyle.physicalSourceOwner(v) == true) and v:hasModData() and\n\t\t\t\t\tv:getModData().OnOff")
end
local function externalSourceCallbacks()
 local env=setmetatable({},{__index=_G});env._G=env
 env.require=function(name)if name=="LSEffects"then return true end;return _G.require(name)end
 chunk(env,"client/InteractionRange.lua",guardRange)
 chunk(env,"client/LSEffectsAux.lua",guardEnding)
 if type(env.LSrefreshJB)~="function"or type(env.JukeboxMusicCheck)~="function"then error("lifestyle-global-source-callback-absent")end
 return env.LSrefreshJB,env.JukeboxMusicCheck
end
local function installExternalMenuGuard()
 local menu=JukeboxMenu
 if type(menu)~="table"then return false end
 for _,name in ipairs(menuCallbacks)do
  if (name=="onPlay"or name=="onTurnOnOff")and type(menu[name])~="function"
   or menu[name]~=nil and type(menu[name])~="function"then return false end
 end
 for _,name in ipairs(menuCallbacks)do
  local current=menu[name]
  if current==nil then
   externalBridge.originalMenus[name]=nil;externalBridge.menus[name]=nil
  else
   local original=current==externalBridge.menus[name]and externalBridge.originalMenus[name]or current
   if type(original)~="function"then return false end
   local wrapper=function(player,object,...)
    if leased(object)then L.releasePhysicalStation(object,"operator-jukebox-control")end
    return original(player,object,...)
   end
   externalBridge.originalMenus[name]=original
   externalBridge.menus[name]=wrapper
   menu[name]=wrapper
  end
 end
 externalBridge.menu=menu
 return true
end
ensureExternalBridge=function()
 if not enabled()or not externalSelected()then return false end
 if externalBridge.ready and stationPhysicalEnabled()then return true end
 if type(_G.LSrefreshJB)~="function"or type(_G.JukeboxMusicCheck)~="function"then externalBridge.ready=false;return false end
 local ok,range,ending=pcall(externalSourceCallbacks)
 if not ok or not installExternalMenuGuard()then externalBridge.ready=false;return false end
 externalBridge.originalRange=_G.LSrefreshJB==externalBridge.range and externalBridge.originalRange or _G.LSrefreshJB
 externalBridge.originalEnding=_G.JukeboxMusicCheck==externalBridge.ending and externalBridge.originalEnding or _G.JukeboxMusicCheck
 externalBridge.range=range;externalBridge.ending=ending
 _G.LSrefreshJB=range;_G.JukeboxMusicCheck=ending
 externalBridge.ready=true
 return true
end
local function maintainExternalBridge()
 if externalSelected()then return ensureExternalBridge()end
 if _G.LSrefreshJB==externalBridge.range then _G.LSrefreshJB=externalBridge.originalRange end
 if _G.JukeboxMusicCheck==externalBridge.ending then _G.JukeboxMusicCheck=externalBridge.originalEnding end
 if JukeboxMenu==externalBridge.menu then
  for name,wrapper in pairs(externalBridge.menus)do
   if JukeboxMenu[name]==wrapper then JukeboxMenu[name]=externalBridge.originalMenus[name]end
  end
 end
 externalBridge.ready=false
 return false
end
local function sample(body)
 local r={};for _,name in ipairs({"Boredom","Stress","Unhappiness","Endurance","Fatigue","Pain"})do
  local value=LSUtil.getCharacterMood(body,name);if finite(value)then r[name]=value end
 end;local d=body:getModData();r.Embarrassed=d.LSMoodles and d.LSMoodles.Embarrassed and d.LSMoodles.Embarrassed.Value;return r
end
local function concept(id)
 local K=SAO.ConceptKnowledge;local v=K and K.infer and K.infer(id,"music","recreation")
 local p=v and v.actorId==id and v.paths and v.paths[1]
 return p and p.status=="expectation"and p.evidenceIds and #p.evidenceIds>0 and plain(p)or nil
end
local function observations(id,body)return SAO.Perception.leisureObjects(id,body)end
local function objectFor(id,body,key)return SAO.Perception.resolveLeisureObject(id,body,key)end
local function power(object)
 local square=object and object:getSquare();return square and ((SandboxVars.ElecShutModifier>-1
  and GameTime:getInstance():getNightsSurvived()<SandboxVars.ElecShutModifier)or square:haveElectricity())
end
local function near(body,object)
 return object and body:getZ()==object:getZ()and math.abs(body:getX()-(object:getX()+.5))<=1.5
  and math.abs(body:getY()-(object:getY()+.5))<=1.5
end
local function objectState(object)
 local d=object:getModData();local r={};for _,k in ipairs({"OnOff","OnPlay","Style","genre","Length","OnPlayTime","JukeNoObject"})do r[k]=plain(d[k])end;return r
end
local valid,finish,bindReaction
local function admitted(a)
 local w=a.work;local P=SAO.ProceduralPlanning;local v=P and P.hobbyAdmission and P.hobbyAdmission(w.actorId,w.purposeId,w.workId)
 return v and v.ownerName==OWNER and v.workId==w.workId and v.sequence==w.sequence
end
local function effectAllowed(a,actor)
 return runtime[a.work.actorId]==a and a.body==actor and a.started and a.callback and valid(a)and admitted(a)
end
local function skill(a,actor,module,command,args)
 if module~="LS"or command~="AddXP"or not effectAllowed(a,actor)or not args or args[1]~="Music"or not finite(args[2])or args[2]<0 then error("unbound-lifestyle-source-command:"..tostring(command))end
 if args[2]==0 then return end
 local r=rec(a.work.actorId);r.lifestyleSkillSequence=(r.lifestyleSkillSequence or 0)+1
 local request={actorId=a.work.actorId,workId=a.work.workId,purposeId=a.work.purposeId,workSequence=a.work.sequence,
  sequence=r.lifestyleSkillSequence,perkName="Music",amount=args[2],atHours=now(),sourceId=SOURCE,revision=a.work.revision,status="requested",
  nativeProgress={sourceCallback=a.callback,sourceInvocationSequence=a.invocation,actionStarted=true,jobDelta=a.action and a.action:getJobDelta()or 0}}
 a.skillRequests=a.skillRequests or {};a.skillRequests[request.sequence]=plain(request)
 r.lifestyleSkillRequests=r.lifestyleSkillRequests or {};r.lifestyleSkillRequests[#r.lifestyleSkillRequests+1]=plain(request)
 if #r.lifestyleSkillRequests>64 then table.remove(r.lifestyleSkillRequests,1)end
 if SAO.LeisureSkill and SAO.LeisureSkill.consume then SAO.LeisureSkill.consume(a.work.actorId,actor,OWNER,a.work.sequence,request.sequence)end
end
local function environment(body,holder)
 local env=setmetatable({LS_DJBooth={},LSMoodHandler={PerMin={},PerTenMin={},PerHour={}},LSInteractiveObjs={},events={},modules={}},{__index=_G});env._G=env
 local function currentBody()return holder.actor and holder.actor.body or body end
 env.getPlayer=function()return currentBody()end;env.getNumActivePlayers=function()return 0 end
 env.getSpecificPlayer=function(index)local own=currentBody();return own and index==own:getPlayerNum()and own or nil end
 env.isKeyDown=function(key)local a=holder.actor;return a and a.callback=="update"and a.keys and a.keys[key]==true or false end
 local manager={volume=getSoundManager():getMusicVolume()}
 function manager:getMusicVolume()return self.volume end
 function manager:setMusicVolume(value)self.volume=value end
 function manager:PlayWorldSound(...)return _G.getSoundManager():PlayWorldSound(...)end
 function manager:playUISound(name)return body:getEmitter():playSound(name)end
 env.getSoundManager=function()return manager end
 env.HaloTextHelper=setmetatable({},{__index=function(_,name)
  if name=="getColorRed"or name=="getColorGreen"then return function()return{r=1,g=1,b=1}end end
  return function(actor,text)local a=holder.actor;if a and actor==body and effectAllowed(a,actor)then
   a.notes=a.notes or {};if #a.notes<16 then a.notes[#a.notes+1]={producer=name,text=tostring(text)}end
  end end
 end})
 env.UIManager={FadeIn=function()end}
 env.ISTimedActionQueue=setmetatable({add=function(action)
  local a=holder.actor
  if not a or not effectAllowed(a,body)or action.character~=body or a.reaction then error("unbound-listener-reaction")end
  return ISTimedActionQueue.add(bindReaction(a,action))
 end},{__index=ISTimedActionQueue})
 env.sendClientCommand=function(actor,module,command,args)
  local a=assert(holder.actor)
  if module=="LS"and command=="SavePlayerData"and effectAllowed(a,actor)and args and args[1]==actor:getModData()then
   rec(a.work.actorId).lifestyleNativeModDataAtHours=now();return
  end
  return skill(a,actor,module,command,args)
 end
 env.Events=setmetatable({},{__index=function(t,name)
  local list={};local event={Add=function(fn)list[fn]=true end,Remove=function(fn)list[fn]=nil end}
  env.events[name]=list;rawset(t,name,event);return event
 end})
 env.require=function(name)
  if name=="TimedActions/ISBaseTimedAction"then return ISBaseTimedAction end
  if name=="NPCs/MainCreationMethods"then return true end -- Native actor's registered creation definitions already exist.
  if name=="LSEffectsJukeboxFunctions"or name=="LSEffects"then return true end
  if name=="Properties/Objects/List"then return holder.object and {holder.object}or{}end
  local path="client/"..name..".lua";if not PINS[path]then path="shared/"..name..".lua"end
  if PINS[path]then if env.modules[name]==nil then env.modules[name]=chunk(env,path)or true end;return env.modules[name]end
  error("lifestyle-unassessed-source-module:"..name)
 end
 chunk(env,"shared/LSUtil.lua")
 local original=env.LSUtil.changeCharacterMoodGroup
 env.LSUtil.changeCharacterMoodGroup=function(actor,group)
  local a=holder.actor;if not a or not effectAllowed(a,actor)then error("unbound-lifestyle-source-mood")end
  local before=sample(actor);original(actor,group);a.work.nativeProgress.sourceMoodCalls=(a.work.nativeProgress.sourceMoodCalls or 0)+1
  a.work.nativeProgress.lastSourceMood={before=before,after=sample(actor),group=plain(group),sourceCallback=a.callback}
  a.moodApplied=true
 end
 env.DJSoundboardOverlay={new=function(_,actor,station)
  if actor~=body then error("foreign-dj-presentation")end
  return{initialise=function()end,addToUIManager=function()end,destroy=function()end,
   provenance="presentation-only isolated sink; actual DJ input uses original DJBoothBind and source soundboard"}
 end}
 return env
end
local function invoke(a,callback,fn,...)
 if not valid(a)or not admitted(a)then error("lifestyle-maintained-source-lost")end
 a.callback=callback;a.invocation=(a.invocation or 0)+1
 local ok,value=pcall(fn,...);a.callback=nil
 if not ok then error(value)end;return value
end
local function runEvents(a,name)
 for fn in pairs(a.env.events[name]or {})do invoke(a,"update",fn)end
end
local function sourceMusicMoodles(a)
 local env=a.env
 env.LSMoodleManager={}
 chunk(env,"client/LSMoodleManager.lua",function(code)
  local first=assert(code:find("LSMoodleManager.init = function",1,true))
  local last=assert(code:find("function LSMoodleManager.getMoodle",first,true))
  local setter=assert(code:find("LSMoodleManager.setValue = function",last,true))
  local setterEnd=assert(code:find("local function getMoodleTextureFromDir",setter,true))
  -- The installed UI enables this setter for the operator. This private
  -- state-only owner enables it solely inside its maintained native callback.
  return "local MoodleManagerEnabled=true\n"..code:sub(first,last-1)..code:sub(setter,setterEnd-1)
 end)
 env.LSMoodleManager.init(a.body)
 local setter=env.LSMoodleManager.setValue
 env.LSMoodleManager.setValue=function(name,value)
  if not effectAllowed(a,a.body)then error("unbound-source-moodle-state")end
  return setter(name,value)
 end
 chunk(env,"client/LSEffects/LSCreation.lua",function(code)
  local first=assert(code:find("local function doDjAudienceCalc",1,true))
  local last=assert(code:find("function LSEveryTenMinutes()",first,true))
  local music=assert(code:find("local musicQuality, listened = 0, false",last,true))
  local musicEnd=assert(code:find("if playerData.VanillaMusicResume",music,true))
  return code:sub(first,last-1).."\nsourceDjAudience=doDjAudienceCalc\nfunction sourceMusicAccounting(player) local playerData=player:getModData();local isToneDeaf=player:hasTrait(CharacterTrait.TONEDEAF);local moodle\n"..code:sub(music,musicEnd-1).."\nend\n"
 end)
 chunk(env,"client/LSEffects/LSPerMinute.lua",function(code)
  local first=assert(code:find("local function getMoodTraitMultipliers",1,true))
  local last=assert(code:find("local function doComfortCalc",first,true))
  local adjust=assert(code:find("local function AdjustGeneralLSMoodles",last,true))
  local adjustEnd=assert(code:find("local changeAnimRollWait",adjust,true))
  local result=code:sub(first,last-1)..code:sub(adjust,adjustEnd-1)
  local prefix='local moodles = {"Comfort", "Uncomfortable", "Embarrassed", "PartyGood", "PartyBad", "MusicGood", "MusicBad","DJAudience","MintFresh", "MintCurio","BathHot", "BathCold", "Eureka", "Gloomy"}'
  local pattern=prefix:gsub("(%W)","%%%1");local _,count=result:gsub(pattern,"");if count~=1 then error("source-music-moodle-list-changed")end
  result=result:gsub(pattern,'local moodles = {"Embarrassed", "MusicGood", "MusicBad", "DJAudience"}',1)
  local comfort='adjustComfortNeed(thisPlayer, playerData)';local _,n=result:gsub(comfort:gsub("(%W)","%%%1"),"");if n~=1 then error("source-music-moodle-entry-changed")end
  result=result:gsub(comfort:gsub("(%W)","%%%1"),"",1)
  return result.."\nsourceMusicMoodEffects=AdjustGeneralLSMoodles\n"
 end)
 a.work.nativeProgress.sourceMoodleAdaptation="original music/audience/embarrassment policies and setter; native actor state only, operator UI enable isolated, comfort and other source-family moodles remain with their owners"
end
local function descriptor(id,body,activity,row,path,evidence,extra)
 local d={id="lifestyle:"..id..":"..activity..":"..row.key,actorId=id,family="music",sourceId=SOURCE,revision=revision(path),activity=activity,
  objectKey=row.key,objectObservation=plain(row),bodyToken=body:getModData().SAOExternalToken,evidence=plain(evidence),
  sourceProducer=path,revisionAuthority="audited SHA256 and runtime dual normalized source fingerprints"}
 for k,v in pairs(extra or {})do d[k]=plain(v)end;return d
end
local catalog
local function catalogs()
 if catalog then return catalog end
 local env=setmetatable({},{__index=_G});env._G=env;catalog={dj=chunk(env,"client/TimedActions/PlayDJBoothTracks.lua"),jukebox={}}
 for _,name in ipairs({"Beach","Classical","Country","Disco","Holiday","Jazz","Metal","Muzak","Pop","Rap","RB","Reggae","Rock","Salsa","World"})do
  local tracks=chunk(env,"client/JukeboxTracks/"..name..".lua")
  if type(tracks)=="table"then for _,track in ipairs(tracks)do if type(track)=="table"and type(track.sound)=="string"and type(track.genre)=="string"then catalog.jukebox[#catalog.jukebox+1]=plain(track)end end end
 end;return catalog
end
local function djParts(id,body,object,rows)
 local left,right
 for _,row in ipairs(rows)do
  if row.customName=="Booth"and row.z==object:getZ()and math.abs(row.x-object:getX())<=1 and math.abs(row.y-object:getY())<=1 then
   if row.spriteName=="ls_djbooth_01_0"or row.spriteName=="ls_djbooth_01_3"then left=row end
   if row.spriteName=="ls_djbooth_01_2"or row.spriteName=="ls_djbooth_01_5"then right=row end
  end
 end
 return left and right and objectFor(id,body,left.key)and objectFor(id,body,right.key)and {leftKey=left.key,rightKey=right.key}or nil
end
local function prep(body,object,row)
 local props=object:getSprite():getProperties();local facing=props:has("Facing")and props:get("Facing")
 local squares={S="getS",N="getN",E="getE",W="getW"};local method=squares[facing]
 local square=method and object:getSquare()[method](object:getSquare())
 if not square then return {preparationBlocked="source-facing-square-unavailable"}end
 local ready=body:getZ()==square:getZ()and math.abs(body:getX()-(square:getX()+.5))<=.8 and math.abs(body:getY()-(square:getY()+.5))<=.8
 return {requiresPreparation={frontSquare=not ready,sourceInitialization=type(body:getModData().LSMoodles)~="table"},
  targetX=square:getX()+.5,targetY=square:getY()+.5,targetZ=square:getZ()}
end
local function initialized(body)
 local d=body:getModData();return type(d.LSMoodles)=="table"and type(d.LSMoodles.DJAudience)=="table"
  and type(d.LSMoodles.Embarrassed)=="table"and type(d.LSMoodles.PartyGood)=="table"and type(d.LSMoodles.PartyBad)=="table"
end
local function trackerReady(body)
 local d=body:getModData();return finite(d.VanillaMusicResume)and finite(d.OtherPlayersAroundDancing)
  and finite(d.ListenedToMusic)and finite(d.HaloCooldownCounter)
end
local function initializeTracker(body)
 local env=environment(body,{})
 env.getNumActivePlayers=function()return body:getPlayerNum()+1 end
 chunk(env,"client/XpSystem/PlayerTracker.lua",function(code)return code.."\nsourceTrackerInit=LScheckPlayerTracker\n"end)
 env.sourceTrackerInit();return trackerReady(body)
end
local function voiceReady(body)
 local value=body:getModData().PlayerVoice;return finite(value)and value>=0 and value<=4 and value%1==0
end
local function retireSaved(id)
 local r=rec(id);local saved=r and r.leisureLifestyleWork
 if runtime[id]or not saved then return false end
 saved.status="interrupted";saved.reason="source-runtime-not-revalidated";saved.atHours=now()
 saved.after=plain(saved.lastMeasured);saved.afterCurrent=false;saved.cleanupSucceeded=false
 saved.afterSourceMoodles=nil;saved.nativeProgress=saved.nativeProgress or{}
 saved.nativeProgress.runtimeRevalidated=false
 r.leisureLifestyleOutcomes=r.leisureLifestyleOutcomes or{}
 r.leisureLifestyleOutcomes[#r.leisureLifestyleOutcomes+1]=plain(saved)
 while #r.leisureLifestyleOutcomes>24 do table.remove(r.leisureLifestyleOutcomes,1)end
 r.leisureLifestyleWork=nil
 local P=SAO.ProceduralPlanning;if P and P.consumeHobbyOutcome then P.consumeHobbyOutcome(id,saved.sequence,OWNER)end
 return true
end
local function candidates(id,body,intents)
 if not enabled()or not live(id,body)then return{}end
 maintainExternalBridge()
 retireSaved(id)
 if runtime[id]or not SAO.Needs.workAvailable(body)then return{}end
 local evidence=concept(id);if not evidence then return{}end
 local rows,result=observations(id,body),{};local data=catalogs()
 for n,row in ipairs(rows)do
    local object=objectFor(id,body,row.key)
  if object and power(object)then
   if row.customName=="Jukebox"and stationPhysicalEnabled()then
    local state=object:getModData();local ready=near(body,object)
    local p=prep(body,object,row)
    if p.preparationBlocked then p={requiresPreparation={frontSquare=not ready}}end
    ready=ready and not p.requiresPreparation.frontSquare
    if ready or intents then
     if state.OnOff~="on"then result[#result+1]=descriptor(id,body,"turn-on-jukebox",row,"shared/TimedActions/JukeboxOn.lua",evidence,p)
     else
      result[#result+1]=descriptor(id,body,"turn-off-jukebox",row,"shared/TimedActions/JukeboxOff.lua",evidence,p)
      local styles={}
      for _,track in ipairs(data.jukebox)do if not styles[track.genre]then
       styles[track.genre]=true;local extra=plain(p);extra.track=plain(track)
       local d=descriptor(id,body,"select-jukebox-music",row,"shared/TimedActions/JukeboxPlay.lua",evidence,extra);d.id=d.id..":"..track.genre;result[#result+1]=d
      end end
     end
    end
    elseif row.customName=="Booth"and(row.spriteName=="ls_djbooth_01_1"or row.spriteName=="ls_djbooth_01_4")
     and not originalDJBusy()and not playerDJQueued(object)and not djOwned(object)and djGuardReady()then
    local parts=djParts(id,body,object,rows);local p=prep(body,object,row)
    if p.requiresPreparation then p.requiresPreparation.sourceInitialization=not initialized(body)or not trackerReady(body)end
    if parts and not p.preparationBlocked and (intents or not p.requiresPreparation.frontSquare and not p.requiresPreparation.sourceInitialization)then
     local offered={};local level=body:getPerkLevel(Perks.Music)
     for _,track in ipairs(data.dj)do if not offered[track.mode]and(track.mode=="slow"or track.mode=="medium"and level>=3 or track.mode=="fast"and level>=6 or track.mode=="housemix")then
      offered[track.mode]=true;local extra=plain(p);extra.track=plain(track);extra.parts=plain(parts)
      local d=descriptor(id,body,"perform-dj",row,"shared/TimedActions/PlayDJBoothAction.lua",evidence,extra);d.id=d.id..":"..track.mode;result[#result+1]=d
     end end
    end
   end
  end
 end
 local heard=L.currentHeardMusic and L.currentHeardMusic(id,body)
 if heard and (intents or initialized(body)and trackerReady(body)and voiceReady(body))then
  local binding=plain(heard);binding.atHours=nil
  result[#result+1]={id="lifestyle:"..id..":listen:"..heard.sourceKey,actorId=id,family="music",sourceId=SOURCE,
  revision=revision("client/LSIsListeningEffects.lua"),activity="listen-lifestyle-music",heardMusic=binding,evidence=evidence,
  sourceProducer="client/LSIsListeningEffects.lua",requiresPreparation={sourceInitialization=not initialized(body)or not trackerReady(body),sourceVoice=not voiceReady(body)}}end
 return result
end
function L.offers(id,body)local ok,rows=pcall(candidates,id,body,false);return ok and plain(rows)or{},not ok and tostring(rows)or nil end
function L.intentOffers(id,body)local ok,rows=pcall(candidates,id,body,true);return ok and plain(rows)or{},not ok and tostring(rows)or nil end
function L.prepareActor(id,body)
 if not live(id,body)then return false,"foreign-lifestyle-body"end
 local M=SAO.LeisureMusic
 if not M or not M.prepareActor then return false,"original-source-initializer-unavailable"end
 local ok,reason=M.prepareActor(id,body)
 if ok==true and not trackerReady(body)then
  local initializedOK,value=pcall(initializeTracker,body)
  if not initializedOK or value~=true then return false,"original-tracker-initialization-failed:"..tostring(value)end
 end
 return ok==true and initialized(body)and trackerReady(body)and voiceReady(body),reason
end
-- Read-only current source facts. Each object must have prior personal custody
-- and a fresh native identity/hearing requery; no source renderer is started here.
local function currentHeardMusic(id,body)
 if not enabled()or not live(id,body)then return nil end
 for _,row in ipairs(observations(id,body))do
  if row.customName=="Jukebox"then
   local object=objectFor(id,body,row.key);local d=object and object:getModData()
   if object and power(object)and d.OnOff=="on"and d.OnPlay=="playing"and d.genre~="JukeboxAfterTurnOn"and d.genre~="nothing"
    and d.Emitter and d.OnPlayEMITTER and d.Emitter:isPlaying(d.OnPlayEMITTER)
    and SAO.Perception.canHearLeisureObject(id,body,row,8)==true then
    return{actorId=id,sourceId=SOURCE,revision=revision("client/LSEffects.lua"),sourceKey=row.key,sourceContext="lifestyle-jukebox",
     runtimeInstance=row.runtimeInstance,sourceSoundId=d.OnPlayEMITTER,trackIndex=d.genre,sound=d.genre,style=d.Style,
     sourceGeneration=d.OnPlayTime,range=8,nativeHeard=true,soundObserved=true,objectObservation=plain(row),atHours=now()}
   end
  end
 end
 -- Only personally known maintained performers are queried. The DJ's actual
 -- emitter and typed work remain the owner; no receiver starts another track.
 local known=SAO.Perception.knownPeople and SAO.Perception.knownPeople(id)or{}
 for n,contact in ipairs(known)do
  if n>48 then break end
  local peer=type(contact)=="table"and(contact.id or contact.actorId or contact.personId)or contact
  local a=peer~=id and runtime[peer]
  local action=a and a.action
  if a and a.offer.activity=="perform-dj"and a.started and not a.performed and a.work.status=="active"
   and action and ISTimedActionQueue.hasAction(action)and live(peer,a.body)and valid(a)and admitted(a)
   and a.env.LS_DJBooth.isPlaying==true and a.body:getModData().PlayingInstrument==true
   and SAO.Body and SAO.Body.get(peer)==a.body and a.body:getZ()==body:getZ()and a.body:isOutside()==body:isOutside()
   and body:CanSee(a.body)and action.gameSound and action.gameSound~=0 and a.body:getEmitter():isPlaying(action.gameSound)
   and SAOJavaBridge:canConverseNow(a.body,body,8)==true then
   return {actorId=id,sourceId=SOURCE,revision=a.work.revision,sourceKey="dj:"..peer..":"..a.work.workId,
    sourceContext="lifestyle-dj",performerId=peer,performerWorkId=a.work.workId,performerWorkSequence=a.work.sequence,
    runtimeInstance=a.work.bodyToken,sourceGeneration=a.work.sequence,sourceSoundId=action.gameSound,
    sound=action.audio,trackIndex=action.audio,range=8,nativeHeard=true,soundObserved=true,atHours=now()}
  end
 end
 local M=SAO.LeisureMusic;return M and M.currentPerformerMusic and M.currentPerformerMusic(id,body)or nil
end
function L.currentHeardMusic(id,body)
 local ok,heard=pcall(currentHeardMusic,id,body);return ok and plain(heard)or nil
end
local function heardSame(a,b)
 if not a or not b then return false end
 for _,key in ipairs({"sourceId","revision","sourceKey","sourceContext","runtimeInstance","sourceSoundId","sourceGeneration","trackIndex",
  "performerId","performerWorkId","performerWorkSequence"})do if a[key]~=b[key]then return false end end;return true
end
valid=function(a)
 local id=a.work.actorId;local r=rec(id)
 if runtime[id]~=a or not live(id,a.body)or r.leisureLifestyleWork~=a.work or a.work.status~="active"
  or a.body:getModData().SAOExternalToken~=a.work.bodyToken or not enabled()then return false end
 if a.offer.activity~="listen-lifestyle-music"and a.offer.activity~="perform-dj"
  and not stationPhysicalEnabled()then return false end
 if a.offer.activity=="listen-lifestyle-music"then return heardSame(a.offer.heardMusic,L.currentHeardMusic(id,a.body))end
 local object=objectFor(id,a.body,a.offer.objectKey)
 if object~=a.object or not power(object)or not near(a.body,object)then return false end
 if a.offer.activity=="perform-dj"and(originalDJBusy()or playerDJQueued(object)or djOwned(object,a)or not djGuardReady())then return false end
 if a.offer.parts then return objectFor(id,a.body,a.offer.parts.leftKey)==a.left and objectFor(id,a.body,a.offer.parts.rightKey)==a.right end
 return true
end
djOwned=function(object,except)
 if not object then return false end
 for _,a in pairs(runtime)do
  if a~=except and a.object==object and a.offer.activity=="perform-dj"and a.work.status=="active"then
   -- The queued action owns the booth until finish clears runtime. If planner
   -- admission or body validity changes, advance retires it; the original
   -- menu cannot take the booth in that intervening frame.
   return true
  end
 end
 return false
end
finish=function(a,status,reason)
 if runtime[a.work.actorId]~=a then return false end
 local w=a.work;local r=rec(w.actorId)
 if status=="completed"and not a.proven then status,reason="interrupted","original-source-terminal-unproven"end
 local measured=a.lastMeasured
 if a.body:getModData().SAOExternalToken==w.bodyToken then local measuredOK,value=pcall(sample,a.body);if measuredOK then measured=value end end
 w.status=status;w.reason=reason;w.atHours=now();w.after=plain(measured);w.cleanupSucceeded=a.cleanupSucceeded==true
 w.nativeProgress.notes=plain(a.notes);w.nativeProgress.sourcePendingMoods=a.env and plain(a.env.LSMoodHandler)
 w.afterSourceMoodles=a.body:getModData().SAOExternalToken==w.bodyToken and plain(a.body:getModData().LSMoodles)or nil
 w.afterObjectState=a.object and objectState(a.object)or nil
 r.leisureLifestyleOutcomes=r.leisureLifestyleOutcomes or {};r.leisureLifestyleOutcomes[#r.leisureLifestyleOutcomes+1]=plain(w)
 while #r.leisureLifestyleOutcomes>24 do table.remove(r.leisureLifestyleOutcomes,1)end
 r.leisureLifestyleWork=nil;runtime[w.actorId]=nil
 if a.action then ownedDJActions[a.action]=nil end
 local P=SAO.ProceduralPlanning;if P and P.consumeHobbyOutcome then P.consumeHobbyOutcome(w.actorId,w.sequence,OWNER)end;return true
end
function L.work(id)local a=runtime[id];local r=rec(id);return a and r and r.leisureLifestyleWork==a.work and plain(a.work)or nil end
function L.outcome(id,sequence)
 local r=rec(id);for _,w in ipairs(r and r.leisureLifestyleOutcomes or {})do if w.sequence==sequence then return plain(w)end end
end
function L.skillRequest(id,workSequence,sequence)
 local a=runtime[id];local row=a and a.skillRequests and a.skillRequests[sequence]
 if row and a.work.sequence==workSequence and a.started and a.action and ISTimedActionQueue.hasAction(a.action)
  and valid(a)and admitted(a)then return plain(row)end
end
local function selectedCell(object)
 return{getGridSquare=function(_,x,y,z)
  if x~=object:getX()or y~=object:getY()or z~=object:getZ()then return nil end
  return{getObjects=function()return{size=function()return 1 end,get=function(_,n)return n==0 and object or nil end}end}
 end}
end
local function physicalCurrent(core)
 local a=core.holder.actor;local w=a and a.work;local r=w and rec(w.actorId)
 if not w or core.body~=a.body or core.record~=r or core.bodyToken~=w.bodyToken
  or a.body:getModData().SAOExternalToken~=core.bodyToken or not live(w.actorId,a.body)
  or not stationPhysicalEnabled()or objectFor(w.actorId,a.body,core.key)~=core.object or not power(core.object)then return false end
 if runtime[w.actorId]==a and r.leisureLifestyleWork==w and w.status=="active"then return admitted(a)end
 -- A completed native station choice leaves its one physical source running.
 -- Only this private originating work, paired with its canonical receipt, retains it.
 if w.status~="completed"or not a.proven then return false end
 for _,saved in ipairs(r.leisureLifestyleOutcomes or{})do
  if saved.sequence==w.sequence and saved.workId==w.workId and saved.purposeId==w.purposeId
   and saved.actorId==w.actorId and saved.bodyToken==core.bodyToken and saved.sourceId==w.sourceId
   and saved.revision==w.revision and saved.status=="completed"then return true end
 end
 return false
end
function L.physicalSourceOwner(object)
 -- Boolean physical lease only: no actor, purpose or private source data escapes.
 if not object then return false end
 if djOwned(object)then return true end
 for _,core in pairs(physicalOwners)do
  if core.object==object then local ok,current=pcall(physicalCurrent,core);return ok and current==true end
 end
 return false
end
function L.releasePhysicalStation(object,reason)
 if not object then return false end
 for key,core in pairs(physicalOwners)do
  if core.object==object then
   local a=core.holder.actor
   if a and runtime[a.work.actorId]==a then L.interrupt(a.work.actorId,a.body,reason or"station-released")end
   local song=core.holder.song
   if song then pcall(function()song.emitter:stopSound(song.handle)end)end
   for _,sound in ipairs(core.holder.ambient or{})do pcall(function()sound.emitter:stopSound(sound.handle)end)end
   physicalOwners[key]=nil
   return true
  end
 end
 return false
end
local function ownedDJAction(action)
 local a=ownedDJActions[action]
 return a~=nil and a.action==action and a.offer.activity=="perform-dj"
  and runtime[a.work.actorId]==a
end
local function blockedOriginalDJAction(action)
 return type(action)=="table"and action.Type=="PlayDJBoothAction"and action.DJBooth~=nil
  and not ownedDJAction(action)and L.physicalSourceOwner(action.DJBooth)==true
end
local function qualifiedDJSource()
 if djGuard.qualified~=nil then return djGuard.qualified end
 if not enabled()then return false end
 local env=setmetatable({},{__index=_G});env._G=env
 local ok=pcall(function()
  chunk(env,"client/DJBoothContextMenu.lua",function(code)
   if not code:find("ISTimedActionQueue.add(PlayDJBoothAction:new(player, DJBooth",1,true)then error("dj-menu-queue-site-changed")end
   return "return true"
  end)
  chunk(env,"shared/TimedActions/PlayDJBoothAction.lua",function(code)
   if not code:find("function PlayDJBoothAction:isValid()",1,true)
    or not code:find("function PlayDJBoothAction:new(character, DJBooth",1,true)then error("dj-action-site-changed")end
   return "return true"
  end)
 end)
 djGuard.qualified=ok
 return ok
end
local function releaseGuardedDJClass()
 if djGuard.actionClass and djGuard.actionClass.isValid==djGuard.validWrapper then
  djGuard.actionClass.isValid=djGuard.originalValid
 end
 djGuard.actionClass=nil;djGuard.originalValid=nil;djGuard.validWrapper=nil
end
local function releaseGuardedDJMenu()
 if djGuard.menu and djGuard.menu.onPlay==djGuard.menuWrapper then
  djGuard.menu.onPlay=djGuard.originalMenu
 end
 djGuard.menu=nil;djGuard.originalMenu=nil;djGuard.menuWrapper=nil
end
djGuard.restore=function()
 djGuard.active=false
 releaseGuardedDJMenu()
 if djGuard.queue and djGuard.queue.add==djGuard.queueWrapper then djGuard.queue.add=djGuard.originalAdd end
 releaseGuardedDJClass()
end
installOriginalDJGuard=function()
 if not djGuard.active then return false end
 if not qualifiedDJSource()then return false end
 local queue=ISTimedActionQueue
 if type(queue)=="table"and type(queue.add)=="function"and queue.add~=djGuard.queueWrapper then
  local original=queue.add
  local wrapper=function(action,...)
   if djGuard.active and blockedOriginalDJAction(action)then return false end
   return original(action,...)
  end
  djGuard.queue=queue;djGuard.originalAdd=original;djGuard.queueWrapper=wrapper;queue.add=wrapper
 end
 local class=PlayDJBoothAction
 if class~=djGuard.actionClass then releaseGuardedDJClass()end
 if type(class)=="table"and class.Type=="PlayDJBoothAction"and type(class.new)=="function"
  and type(class.isValid)=="function"and djGuard.actionClass==nil then
  local original=class.isValid
  local wrapper=function(action,...)
   if djGuard.active and blockedOriginalDJAction(action)then return false end
   return original(action,...)
  end
  djGuard.actionClass=class;djGuard.originalValid=original;djGuard.validWrapper=wrapper;class.isValid=wrapper
 end
 local menu=DJBoothMenu
 if menu~=djGuard.menu then releaseGuardedDJMenu()end
 if type(menu)~="table"or type(menu.onPlay)~="function"or type(menu.walkToFront)~="function"then return false end
 if not djGuard.menu then
  djGuard.menu=menu;djGuard.originalMenu=menu.onPlay
 end
 if menu.onPlay==djGuard.originalMenu then
  if not djGuard.menuWrapper then
   local original=djGuard.originalMenu
   djGuard.menuWrapper=function(worldobjects,player,object,...)
    if djGuard.active and L.physicalSourceOwner(object)then
     if HaloTextHelper and HaloTextHelper.addText then
      pcall(HaloTextHelper.addText,player,"The booth is in use.")
     end
     return false
    end
    return original(worldobjects,player,object,...)
   end
  end
  menu.onPlay=djGuard.menuWrapper
 end
 return menu.onPlay==djGuard.menuWrapper
end
djGuardReady=function()
 installOriginalDJGuard()
 return djGuard.qualified==true and djGuard.menu==DJBoothMenu and djGuard.menuWrapper~=nil
  and DJBoothMenu.onPlay==djGuard.menuWrapper and djGuard.queue==ISTimedActionQueue
  and ISTimedActionQueue.add==djGuard.queueWrapper and djGuard.actionClass==PlayDJBoothAction
  and PlayDJBoothAction.isValid==djGuard.validWrapper
end
local function physicalCore(a)
 local key=a.offer.objectKey;local core=physicalOwners[key]
 if core and core.object==a.object and core.body==a.body and core.bodyToken==a.work.bodyToken and core.record==rec(a.work.actorId)then core.holder.actor=a;core.actorId=a.work.actorId;core.env.LSrefreshJB(a.body);return core end
 local holder={actor=a,object=a.object};local env=environment(a.body,holder);env.getCell=function()return selectedCell(a.object)end
 env.LS_AMcache={truemusic=LS_AMcache and LS_AMcache.truemusic,truemusic_cached=true}
 env.LS_PatchUtils=LS_PatchUtils
 env.JukeboxMenu={configVol=JukeboxMenu and JukeboxMenu.configVol or 1,config3D=JukeboxMenu and JukeboxMenu.config3D}
 env.captureSourceAmbient=function(emitter,handle)
  holder.ambient=holder.ambient or{};holder.ambient[#holder.ambient+1]={emitter=emitter,handle=handle}
 end
 chunk(env,"client/LSEffects.lua")
 local sourceSend=env.OnJukeboxSendSong
 env.OnJukeboxSendSong=function(...)
  local d=holder.object:getModData();local previous=d.Emitter;local previousHandle=d.OnPlayEMITTER
  local result=sourceSend(...)
  if d.Emitter and d.OnPlayEMITTER and (d.Emitter~=previous or d.OnPlayEMITTER~=previousHandle)then
   holder.song={emitter=d.Emitter,handle=d.OnPlayEMITTER}
  end
  return result
 end
 chunk(env,"client/LSEffectsJukeboxFunctions.lua",function(code)
  local original='audioLoop = emitterLoop:playSoundImpl("JukeboxRunning", false, Jukebox);'
  local _,count=code:gsub(original:gsub("(%W)","%%%1"),"");if count~=1 then error("source-ambient-trace-site-changed")end
  return(code:gsub(original:gsub("(%W)","%%%1"),original.."captureSourceAmbient(emitterLoop,audioLoop);",1))
 end)
 chunk(env,"client/DiscoStateChange.lua")
 chunk(env,"client/LSEffectsAux.lua")
 -- Keep the original range/power/recovery branch. Presentation-only lighting
 -- follows this branch in the installed source and remains operator-owned.
 chunk(env,"client/InteractionRange.lua",function(code)
  local first=assert(code:find("function LSrefreshJB(playerObj)",1,true))
  local last=assert(code:find("end--range",first,true))+ #"end--range"-1
  return code:sub(1,last).."\nend end end\n"
 end)
 core={object=a.object,env=env,holder=holder,key=key,actorId=a.work.actorId,body=a.body,bodyToken=a.work.bodyToken,record=rec(a.work.actorId)};physicalOwners[key]=core
 env.LSrefreshJB(a.body);return core
end
local function djPolicy(a)
 local action=a.action;a.keys={};a.inputChosen=false;if action.keyPause or action.Failstate or not action.gameSound or action.gameSound==0 then return end
 local level=a.body:getPerkLevel(Perks.Music)
 local stress=LSUtil.getCharacterMood(a.body,"Stress")
 -- The choice requests original controls; original skill/failure RNG is untouched.
 -- An unfamiliar performer commonly refrains, and stress encourages simpler mixing.
 local roll=ZombRand(100)
 if stress>.5 and action.mode~="slow"then a.keys[Keyboard.KEY_DOWN]=true
 elseif roll<math.min(30,level*3)then
  if level>=6 and action.mode=="medium"or level>=3 and action.mode=="slow"then a.keys[Keyboard.KEY_UP]=true
  else a.env.LS_DJBooth.keyLEFTRIGHT=true end
 elseif roll<math.min(55,10+level*4)then
  invoke(a,"update",a.env.LS_DJBooth.keyPress,79)
 end
 local chosen=false;for _ in pairs(a.keys)do chosen=true;break end
 a.inputChosen=chosen or a.env.LS_DJBooth.keyLEFTRIGHT==true
 a.work.nativeProgress.lastInput={musicLevel=level,stress=stress,roll=roll,keys=plain(a.keys),uncertain=true,
  producer="actor-scoped source input; original key delay, modes, soundboard and failure remain authoritative"}
end
local function retireCaptured(a,self)
 if a.body:getModData().SAOExternalToken~=a.work.bodyToken then return false end
 local ok=true;local function attempt(fn)local ran=pcall(fn);ok=ran and ok end
 if self.gameSound and self.gameSound~=0 then attempt(function()a.body:getEmitter():stopSound(self.gameSound)end)end
 if self.sound then attempt(function()a.body:getEmitter():stopSound(self.sound)end)end
 if a.env and a.env.LS_DJBooth.loopBeat and a.env.LS_DJBooth.loopBeat~=0 then attempt(function()a.body:getEmitter():stopSound(a.env.LS_DJBooth.loopBeat)end)end
 if a.offer.activity=="perform-dj"then
  attempt(function()a.body:getModData().PlayingInstrument=false;a.env.LS_DJBooth.isPlaying=false end)
  if self.DJBoothOverlay and self.DJBoothOverlay~=0 then attempt(function()self.DJBoothOverlay:destroy()end)end
 end
 attempt(function()ISBaseTimedAction.stop(self)end);return ok
end
local function bindAction(a,action)
 local native={start=action.start,update=action.update,perform=action.perform,stop=action.stop,isValid=action.isValid,waitToStart=action.waitToStart}
 a.action=action
 if a.offer.activity=="perform-dj"then ownedDJActions[action]=a end
 action.isValid=function(self)return self==action and valid(a)and admitted(a)and native.isValid(self)end
 action.waitToStart=function(self)return self:isValid()and native.waitToStart and native.waitToStart(self)or false end
 action.start=function(self)
  if not self:isValid()or a.started then return end;a.started=true
  local ok,err=pcall(invoke,a,"update",native.start,self)
  if not ok then L.interrupt(a.work.actorId,a.body,"source-start-failed:"..tostring(err));self:forceStop()end
 end
 action.update=function(self)
  if not self:isValid()or not a.started then L.interrupt(a.work.actorId,a.body,"current-source-lost");self:forceStop();return end
  local ok,err=pcall(function()
   local previousHandle=self.gameSound
   if a.offer.activity=="perform-dj"then
    local handle=self.gameSound
    if a.heardHandle and handle==a.heardHandle and not a.body:getEmitter():isPlaying(handle)and not self.Failstate
     and a.inputRetiredHandle~=handle
     and a.heardAudio~= "dj_booth_fail1"and a.heardAudio~="dj_booth_fail2"and a.heardAudio~="dj_booth_fail3"then
     a.sourceTrackEnded=true;self:forceComplete();return
    end
    djPolicy(a)
   end
   invoke(a,"update",native.update,self);a.keys={}
   if a.offer.activity=="perform-dj"and a.inputChosen and previousHandle and previousHandle~=0
    and self.gameSound==previousHandle and not a.body:getEmitter():isPlaying(previousHandle)then
    a.inputRetiredHandle=previousHandle
   end
   a.work.nativeProgress.observedUpdates=(a.work.nativeProgress.observedUpdates or 0)+1
   if a.offer.activity=="perform-dj"and self.gameSound and self.gameSound~=0 and a.body:getEmitter():isPlaying(self.gameSound)then
    a.heardHandle=self.gameSound;a.heardAudio=self.audio;a.work.nativeProgress.soundObserved=true
    a.work.nativeProgress.sound=self.audio;a.work.nativeProgress.sourceMode=self.mode
    a.work.nativeProgress.sourceFailure=self.audio=="dj_booth_fail1"or self.audio=="dj_booth_fail2"or self.audio=="dj_booth_fail3"
   end
   a.lastMeasured=sample(a.body);a.work.lastMeasured=plain(a.lastMeasured)
  end)
  if not ok then L.interrupt(a.work.actorId,a.body,"source-update-failed:"..tostring(err));self:forceStop()end
 end
 action.perform=function(self)
  if not self:isValid()or not a.started or a.performed or not ISTimedActionQueue.hasAction(self)then return end
  if a.offer.activity=="perform-dj"then if not a.sourceTrackEnded or not a.work.nativeProgress.soundObserved then self:stop();self:forceStop();return end
  elseif self:getJobDelta()<1 then return end
  a.performed=true
  local ok,err=pcall(invoke,a,"perform",native.perform,self);a.cleanupSucceeded=ok
  if not ok then a.work.nativeProgress.cleanupAfterSourceFault=retireCaptured(a,self);a.cleanupSucceeded=false end
  local state=a.object and a.object:getModData()
  a.proven=ok and(a.offer.activity=="perform-dj"or a.offer.activity=="turn-on-jukebox"and state.OnOff=="on"
   or a.offer.activity=="turn-off-jukebox"and state.OnOff=="off"
   or a.offer.activity=="select-jukebox-music"and state.Style==a.offer.track.genre and state.genre==a.offer.track.sound
    and state.OnPlay=="playing"and state.Emitter and state.OnPlayEMITTER and state.Emitter:isPlaying(state.OnPlayEMITTER))
  a.lastMeasured=sample(a.body);a.work.lastMeasured=plain(a.lastMeasured);finish(a,a.proven and "completed"or"interrupted",not a.proven and("source-perform-unproven:"..tostring(err))or nil)
 end
 action.stop=function(self)
  if runtime[a.work.actorId]~=a then return end
  local ok=true
  if live(a.work.actorId,a.body)and a.started and valid(a)and admitted(a)then
   ok=pcall(invoke,a,"stop",native.stop,self)
   if not ok then a.work.nativeProgress.cleanupAfterSourceFault=retireCaptured(a,self)end
  else
   -- Retire only retained same-generation handles; dead bodies receive no mood/XP.
   if a.body:getModData().SAOExternalToken==a.work.bodyToken then
    ok=retireCaptured(a,self)
   else ok=false end
  end
  a.cleanupSucceeded=ok;finish(a,"interrupted",a.failureReason or "source-stopped")
 end
 return action
end
bindReaction=function(a,action)
 local native={start=action.start,update=action.update,perform=action.perform,stop=action.stop,isValid=action.isValid}
 a.reaction=action
 action.isValid=function(self)return self==a.reaction and valid(a)and admitted(a)and native.isValid(self)end
 local function retire(self,completed)
  if runtime[a.work.actorId]~=a or a.reaction~=self then return end
  local ok=true
  if completed and self:isValid()and self:getJobDelta()>=1 then
   ok=pcall(invoke,a,"perform",native.perform,self)
   a.work.nativeProgress.sourceReactionCompleted=ok
  else
   if self.gameSound and self.gameSound~=0 then ok=pcall(function()a.body:getEmitter():stopSound(self.gameSound)end)end
   local baseOK=pcall(ISBaseTimedAction.stop,self);ok=baseOK and ok
  end
  a.reaction=nil
  if a.moodApplied and completed and ok then a.proven=true;a.cleanupSucceeded=true;finish(a,"completed")
  elseif not completed or not ok then a.cleanupSucceeded=ok;finish(a,"interrupted","source-listener-reaction-stopped")end
 end
 action.start=function(self)if self:isValid()then
  local ok=pcall(invoke,a,"update",native.start,self);if not ok then retire(self,false)end
 end end
 action.update=function(self)if self:isValid()then
  local ok=pcall(invoke,a,"update",native.update,self);if not ok then retire(self,false)end
 else retire(self,false)end end
 action.perform=function(self)if self:getJobDelta()>=1 then retire(self,true)end end
 action.stop=function(self)retire(self,false)end
 return action
end
function L.begin(id,body,offer,purposeId)
 maintainExternalBridge()
 if not live(id,body)or runtime[id]or type(offer)~="table"or type(purposeId)~="string"then return false,"invalid-lifestyle-owner"end
 local selected
 for _,row in ipairs(L.offers(id,body))do if same(row,offer)then selected=row;break end end
 if not selected then return false,"stale-or-foreign-lifestyle-offer"end
 if selected.activity=="perform-dj"then
  local object=objectFor(id,body,selected.objectKey)
   if originalDJBusy()or playerDJQueued(object)or djOwned(object)or not djGuardReady()then
   return false,"dj-booth-physical-owner-busy"
  end
 end
 if selected.activity~="listen-lifestyle-music"and selected.activity~="perform-dj"
  and not stationPhysicalEnabled()then return false,"physical-station-owned-by-external-source"end
 if selected.requiresPreparation and selected.requiresPreparation.sourceInitialization then return false,"source-actor-not-initialized"end
 retireSaved(id)
 local r=rec(id);r.lifestyleSequence=(r.lifestyleSequence or 0)+1
 local w={actorId=id,sequence=r.lifestyleSequence,workId="lifestyle:"..id..":"..r.lifestyleSequence,purposeId=purposeId,family="music",sourceId=SOURCE,
  revision=selected.revision,activity=selected.activity,objectKey=selected.objectKey,itemKey=selected.itemKey,itemType=selected.itemType,
  bodyToken=body:getModData().SAOExternalToken,bodyGenerationKnown=body:getModData().SAOExternalToken~=nil,admittedAtHours=now(),atHours=now(),status="prepared",
  nativeOwner=selected.sourceProducer,nativeProgress={observedUpdates=0,sourceMoodCalls=0},sourceOffer=plain(selected),before=sample(body),beforeSourceMoodles=plain(body:getModData().LSMoodles)}
 local a={body=body,offer=selected,work=w};runtime[id]=a;r.leisureLifestyleWork=w
 if not SAO.ProceduralPlanning.admitHobbyWork(id,purposeId,w.sequence,OWNER)then runtime[id]=nil;r.leisureLifestyleWork=nil;return false,"planner-refused-lifestyle"end
 w.status="active"
 local ok,err=pcall(function()
  if selected.activity=="listen-lifestyle-music"then
   local holder={actor=a};a.env=environment(body,holder);a.started=true
   chunk(a.env,"client/TimedActions/PlayerVoiceTracks.lua")
   for _,name in ipairs({"ToneDeafSuffering","BooingMusician","PraiseMusician"})do chunk(a.env,"shared/TimedActions/"..name..".lua")end
   chunk(a.env,"client/LSIsListeningEffects.lua");chunk(a.env,"client/ZLSUpdate.lua")
   sourceMusicMoodles(a)
   -- Export only the original receiver's Jukebox function. Its remaining
   -- operator-wide scanner is not a source of personally acquired objects.
   chunk(a.env,"client/Properties/Objects/Handler.lua",function(code)
    local first=assert(code:find("LSInteractiveObjs.Jukebox = function",1,true))
    local last=assert(code:find("LSInteractiveObjs.DiscoBall",first,true))
    return code:sub(first,last-1)
   end)
   chunk(a.env,"client/DiscoStateChange.lua",function(code)
    local first=assert(code:find("if not playerObj:hasTrait(CharacterTrait.DEAF)",1,true))
    local last=assert(code:find("if LS_DJBooth.isPlaying or LS_DJBooth.isPlayingMic",first,true))
    return "function sourceJukeboxListening(playerObj) local playerData=playerObj:getModData()\n"..code:sub(first,last-1).."\nend\n"
   end)
   for fn in pairs(a.env.events.OnGameStart or {})do invoke(a,"update",fn)end
   return
  end
  a.object=objectFor(id,body,selected.objectKey);w.beforeObjectState=objectState(a.object)
  local action
  if selected.activity=="perform-dj"then
   a.left=objectFor(id,body,selected.parts.leftKey);a.right=objectFor(id,body,selected.parts.rightKey)
   a.env=environment(body,{actor=a});chunk(a.env,"shared/Attributes/DjBooth_defs.lua");chunk(a.env,"client/DJBoothBind.lua")
   chunk(a.env,"client/ZLSUpdate.lua");sourceMusicMoodles(a)
   for fn in pairs(a.env.events.OnGameStart or{})do a.started=true;invoke(a,"update",fn);a.started=nil end
   local class=chunk(a.env,"shared/TimedActions/PlayDJBoothAction.lua");local t=selected.track
   action=class:new(body,a.object,t.sound,t.mode,t.length,0,0,0,"Bob_PlayDJDefault",false)
  else
   local core=physicalCore(a);core.holder.actor=a;a.env=core.env
   if selected.activity=="turn-on-jukebox"then chunk(a.env,"shared/TimedActions/JukeboxOn.lua");action=a.env.JukeboxOn:new(body,a.object,"JukeboxTurnOn","JukeboxRunning")
   elseif selected.activity=="turn-off-jukebox"then chunk(a.env,"shared/TimedActions/JukeboxOff.lua");action=a.env.JukeboxOff:new(body,a.object,"JukeboxTurnOff","JukeboxTurnOff")
   else chunk(a.env,"shared/TimedActions/JukeboxPlay.lua");action=a.env.JukeboxPlay:new(body,a.object,"JukeboxSwitch",selected.track.sound,0,selected.track.genre)end
  end
  ISTimedActionQueue.add(bindAction(a,action))
 end)
 if not ok then L.interrupt(id,body,"source-admission-failed:"..tostring(err));return false,tostring(err)end
 return true,w.sequence
end
function L.advance(id,body)
 local a=runtime[id];if not a then
  retireSaved(id);return false
 end
 if a.body~=body then return false end
 if not valid(a)or not admitted(a)then L.interrupt(id,body,"maintained-source-lost");return false end
 if (a.action and not ISTimedActionQueue.hasAction(a.action))or(a.reaction and not ISTimedActionQueue.hasAction(a.reaction))then L.interrupt(id,body,"native-source-queue-lost");return false end
 return true
end
function L.interrupt(id,body,reason)
 local a=runtime[id];if not a or a.body~=body then return false end;a.failureReason=reason or"source-interrupted"
 local action=a.action or a.reaction
 if action then local native=action.action;local stopped=pcall(action.stop,action)
  if runtime[id]==a then
   a.work.nativeProgress.cleanupAfterSourceFault=retireCaptured(a,action);a.cleanupSucceeded=false
   finish(a,"interrupted",a.failureReason..(stopped and ":source-stop-unconfirmed"or":source-stop-failed"))
  end
  if native then pcall(function()native:forceStop()end)end
 else a.cleanupSucceeded=true;finish(a,"interrupted",a.failureReason)end
 return true
end
function L.reset(reason)
 local ids={};for id in pairs(runtime)do ids[#ids+1]=id end
 for _,id in ipairs(ids)do local a=runtime[id];L.interrupt(id,a.body,reason or"source-runtime-reset")end
 for key,core in pairs(physicalOwners)do
  local song=core.holder.song
  if song then pcall(function()song.emitter:stopSound(song.handle)end)end
  for _,sound in ipairs(core.holder.ambient or{})do pcall(function()sound.emitter:stopSound(sound.handle)end)end
  physicalOwners[key]=nil
 end
end
local function accounting(name)
 for id,a in pairs(runtime)do
  local eligibilityOK,eligible=pcall(function()
   return (a.offer.activity=="listen-lifestyle-music"or a.offer.activity=="perform-dj"and a.started)and valid(a)and admitted(a)
  end)
  if not eligibilityOK then L.interrupt(id,a.body,"source-requery-failed")end
  if eligibilityOK and eligible then
   local clock=GameTime.getInstance():getWorldAgeHours();local r=rec(id);r.lifestyleEventClock=r.lifestyleEventClock or {}
   if finite(clock)and (r.lifestyleEventClock[name]==nil or clock>r.lifestyleEventClock[name])then
    r.lifestyleEventClock[name]=clock
    local ok,err=pcall(function()
     if name=="EveryOneMinute"then
      invoke(a,"update",a.env.sourceMusicMoodEffects,a.body,a.body:getModData())
     end
     if name=="EveryOneMinute"and a.offer.activity=="listen-lifestyle-music"then
      local heard=L.currentHeardMusic(id,a.body)
      local quality=3
      if heard.sourceContext=="performer"then
       local peer=SAO.Body.get(heard.performerId);quality=peer:getPerkLevel(Perks.Music)
       invoke(a,"update",a.env.PlayerIsListeningToMusic,a.body,quality)
      elseif heard.sourceContext=="lifestyle-dj"then
       local peer=SAO.Body.get(heard.performerId);quality=peer:getPerkLevel(Perks.Music)
       invoke(a,"update",a.env.PlayerIsListeningToDJ,a.body,quality,tostring(peer:getUsername()),true)
      else
       local object=objectFor(id,a.body,heard.sourceKey)
       invoke(a,"update",a.env.LSInteractiveObjs.Jukebox,a.body,object)
       invoke(a,"update",a.env.sourceJukeboxListening,a.body)
      end
      a.work.nativeProgress.sourceListenerInvocations=(a.work.nativeProgress.sourceListenerInvocations or 0)+1
     end
     if name=="EveryTenMinutes"then
      if a.offer.activity=="listen-lifestyle-music"then
       invoke(a,"update",a.env.sourceMusicAccounting,a.body)
      else
       local audience=0
       for _,contact in ipairs(SAO.Perception.knownPeople and SAO.Perception.knownPeople(id)or{})do
        local peer=type(contact)=="table"and contact.id or contact
        local actor=peer~=id and SAO.Body and SAO.Body.get(peer)
        if actor and not actor:isDead()and actor:isExistInTheWorld()and a.body:CanSee(actor)
         and actor:getZ()==a.body:getZ()and actor:isOutside()==a.body:isOutside()
         and math.abs(actor:getX()-a.body:getX())<=8 and math.abs(actor:getY()-a.body:getY())<=8 then audience=audience+1 end
       end
       invoke(a,"update",a.env.sourceDjAudience,a.body:getModData().LSMoodles.DJAudience.Value,audience)
       a.work.nativeProgress.sourceAcquiredAudience=audience
      end
     end
     runEvents(a,name);a.lastMeasured=sample(a.body);a.work.lastMeasured=plain(a.lastMeasured)
     a.work.nativeProgress.observedUpdates=a.work.nativeProgress.observedUpdates+1
     if a.offer.activity=="listen-lifestyle-music"and a.moodApplied and not a.reaction then a.proven=true;a.cleanupSucceeded=true;finish(a,"completed")end
    end)
    if not ok then L.interrupt(id,a.body,"source-listener-failed:"..tostring(err))end
   end
  end
 end
end
if Events then
 if Events.OnGameBoot then Events.OnGameBoot.Add(installOriginalDJGuard)end
 if Events.OnGameStart then Events.OnGameStart.Add(installOriginalDJGuard)end
 Events.OnTick.Add(function()
  installOriginalDJGuard()
  maintainExternalBridge()
  for key,core in pairs(physicalOwners)do
   local body=core.holder.actor and core.holder.actor.body
   local ok,current=pcall(physicalCurrent,core)
   if ok and current then
    -- Genuine installed scheduler, once on the actual game callback; no
    -- synthetic time advancement or private copy of the public emitter.
    if core.env.JukeboxMenu then
     core.env.JukeboxMenu.configVol=JukeboxMenu and JukeboxMenu.configVol or 1
     core.env.JukeboxMenu.config3D=JukeboxMenu and JukeboxMenu.config3D
    end
    local ran=pcall(function()core.env.LSrefreshJB(body);core.env.JukeboxMusicCheck(body)end)
    for fn in pairs(core.env.events.OnTick or{})do if not pcall(fn)then ran=false end end
    if not ran then core.schedulerFailure=true end
   else
    local song=core.holder.song
    if song then pcall(function()song.emitter:stopSound(song.handle)end)end
    for _,sound in ipairs(core.holder.ambient or{})do pcall(function()sound.emitter:stopSound(sound.handle)end)end
    physicalOwners[key]=nil
   end
  end
 end)
 Events.EveryOneMinute.Add(function()accounting("EveryOneMinute")end)
 Events.EveryTenMinutes.Add(function()accounting("EveryTenMinutes")end)
 Events.EveryHours.Add(function()accounting("EveryHours")end)
 Events.EveryDays.Add(function()accounting("EveryDays")end)
end
