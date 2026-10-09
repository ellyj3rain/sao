local freshMusic=__fresh
local hooks={}
Events=setmetatable({},{__index=function(t,key)local rows={};hooks[key]=rows;local e={Add=function(fn)rows[#rows+1]=fn end};rawset(t,key,e);return e end})
function __event(name)for _,fn in ipairs(hooks[name]or{})do fn()end end
GameTime={getInstance=function()return{getNightsSurvived=function()return 1 end,getWorldAgeHours=function()return __engineHours end}end}
SandboxVars.ElecShutModifier=-1;SandboxVars.LS={MoodUpdate=5,ModdataUpdate=8};SandboxVars.DayLength=4
Keyboard.KEY_UP='UP';Keyboard.KEY_DOWN='DOWN';Keyboard.KEY_C='C';Keyboard.KEY_A='A';Keyboard.KEY_S='S';Keyboard.KEY_W='W';Keyboard.KEY_D='D'
LS_AMcache={truemusic=false,truemusic_cached=true};LS_PatchUtils={hasCompatMod=function()return false end}
JukeboxMenu={configVol=.7,config3D=true}
getWorld=function()return{getFreeEmitter=function()return __worldEmitter end}end
getSoundManager=function()return{getMusicVolume=function()return __volume end,setMusicVolume=function(_,v)__volume=v end,
 PlayWorldSound=function(_,sound)return __worldEmitter:playSound(sound)end}end
addSound=function()__worldSounds=__worldSounds+1 end
LS_DJBooth={};GTLSCheck=1
local owner='SAO.LeisureLifestyle'
SAO.ProceduralPlanning={admitHobbyWork=function(id,pid,seq,name)
 local w=SAO.LeisureLifestyle.work(id);return __admit and name==owner and pid=='purpose:1'and w and w.sequence==seq
end,hobbyAdmission=function(id,pid,wid)
 local w=SAO.LeisureLifestyle.work(id);if __admit and w and w.workId==wid and w.purposeId==pid then return{ownerName=owner,workId=wid,sequence=w.sequence}end
end,consumeHobbyOutcome=function(id,seq,name)
 assert(name==owner);local w=SAO.LeisureLifestyle.outcome(id,seq);assert(w and w.actorId==id);__consumed=__consumed+1;return true
end}
SAO.LeisureSkill={consume=function(id,body,provider,work,sequence)
 local req=SAO.LeisureLifestyle.skillRequest(id,work,sequence);assert(req and req.nativeProgress.actionStarted);__skillRequests=__skillRequests+1;return true
end}
SAO.Perception.knownPeople=function()return{}end
SAO.Perception.canHearLeisureObject=function(_,body,row,range)return body==__body and row.key=='station'and __hearing and range==8 end
function __freshLifestyle(kind)
 if SAO.LeisureLifestyle then SAO.LeisureLifestyle.reset('fixture-reset')end
 freshMusic();__queued=nil;__engineHours=10;__hearing=true;__power=true;__bodyDead=false;__speakerOn=false;__x=10.5;__y=11.5
 local body=__body;body.isDead=function()return __bodyDead end;body.isExistInTheWorld=function()return true end;body.getPlayerNum=function()return 1 end
 body.hasModData=function()return true end;body.getX=function()return __x end;body.getY=function()return __y end
 body.SetVariable=body.setVariable;body.setX=function(_,x)__x=x end;body.setY=function(_,y)__y=y end;body.stopOrTriggerSound=function(_,h)body:getEmitter():stopSound(h)end
 body.faceThisObject=function()end;body.shouldBeTurning=function()return false end;body.setAnimated=function()end
 body.isRunning=function()return false end;body.isSprinting=function()return false end;body.hasTimedActions=function()return __queued~=nil end
 body.getCurrentState=function()return{equals=function()return true end}end
 body.getInventory=function()return{getItems=function()return{size=function()return 0 end}end}end
 body.isEquippedClothing=function()return false end;body.CanSee=function()return __hearing end
 local md=body:getModData();md.PlayerVoice=0;md.LSMoodles.DJAudience={Value=0};md.OtherPlayersAroundDancing=0;md.ListenedToMusic=-1;md.VanillaMusicResume=0;md.HaloCooldownCounter=0;md.DancingInit=false
 SAO.Body={get=function(id)return id=='person'and body or nil end}
 IdleState={instance=function()return{}end}
 local nativeEmitter=body:getEmitter();nativeEmitter.playSoundImpl=nativeEmitter.playSound
 nativeEmitter.setPos=function()end;nativeEmitter.setVolume=function()end;nativeEmitter.set3D=function()end
 nativeEmitter.stopSoundByName=function(_,name)for handle in pairs(__playing)do __playing[handle]=false end end
 __worldEmitter=nativeEmitter
 local front={getX=function()return 10 end,getY=function()return 11 end,getZ=function()return 0 end}
 local cell={};local square={getX=function()return 10 end,getY=function()return 10 end,getZ=function()return 0 end,
 haveElectricity=function()return __power end,getS=function()return front end}
 local objmd={OnOff='off'}
 local props={CustomName=kind=='dj'and'Booth'or'Jukebox',Facing='S',GroupName='Gramophone'}
 function props:has(k)return self[k]~=nil end;function props:get(k)return self[k]end
 local spriteName=kind=='dj'and'ls_djbooth_01_1'or'ls_jukebox_01_0'
 local obj={getSquare=function()return square end,getX=function()return 10 end,getY=function()return 10 end,getZ=function()return 0 end,
 getModData=function()return objmd end,hasModData=function()return true end,getCell=function()return cell end,
 getSprite=function()return{getName=function()return spriteName end,getProperties=function()return props end}end}
 square.getObjects=function()return{size=function()return 1 end,get=function(_,index)return index==0 and obj or nil end}end
 cell.getGridSquare=function(_,x,y,z)return x==10 and y==10 and z==0 and square or nil end
 body.getSquare=function()return front end
 __objects={{actorId='person',key='station',runtimeInstance='station:1',x=10,y=10,z=0,customName=props.CustomName,spriteName=spriteName}}
 __objectHandles={station=obj}
 if kind=='dj'then
  for index,part in ipairs({'ls_djbooth_01_0','ls_djbooth_01_2'})do
   local key='part'..index;__objects[#__objects+1]={actorId='person',key=key,runtimeInstance=key..':1',x=10+index-1,y=10,z=0,customName='Booth',spriteName=part}
   __objectHandles[key]={getSquare=function()return square end}
  end
 end
 __station=obj;return obj
end
function __offer(activity)
 local rows,reason=SAO.LeisureLifestyle.offers('person',__body)
 for _,row in ipairs(rows)do if row.activity==activity then return row end end
 error('missing offer '..activity..':'..tostring(reason))
end
function __start(activity)
 local offer=__offer(activity);local ok,sequence=SAO.LeisureLifestyle.begin('person',__body,offer,'purpose:1')
 assert(ok,tostring(sequence));if __queued then local a=__queued;a:start();assert(__queued,tostring(SAO.LeisureLifestyle.outcome("person",sequence)and SAO.LeisureLifestyle.outcome("person",sequence).reason))end;return sequence,offer
end
function __complete()__delta=1;assert(__queued);__queued:perform()end
