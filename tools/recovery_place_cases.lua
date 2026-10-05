-- Controlled action scheduling around production RecoveryPose; native geometry/animator has a separate probe.
local checks=0
TchAL={stateVariableOnGround="SleepStateOnGround"}
getActivatedMods=function()return {contains=function(_,id)return id=="LeanAndLie"or id=="TchernoLib"end}end
isClient=function()return false end;isServer=function()return false end
local function check(name,value) if not value then error("RECOVERY_PLACE_LUA:"..name) end;checks=checks+1 end
local nativeBedAction=ISGetOnBedAction
local record,owned,available,clear,poseSeen={},true,true,true,false
local bed={getObjectIndex=function()return 0 end,getProperties=function()return {get=function(_,key)return key=="Facing" and "E" or "goodBed"end}end}
local body={x=10.5,y=20.5,z=0,vars={},onBed=false,bed=nil,furniture=nil,bedType=nil}
function body:getX()return self.x end function body:getY()return self.y end function body:getZ()return self.z end
function body:setX(x)self.x=x end function body:setY(y)self.y=y end
function body:getModData()return {SAOPersonId="person"}end
function body:clearVariable(key)self.vars[key]=nil end
function body:setVariable(key,value)self.vars[key]=value end
function body:getVariableString(key)return self.vars[key]end
function body:getVariableBoolean(key)return self.vars[key]==true end
function body:isOnBed()return self.onBed end
function body:getCurrentStateName()return "IdleState"end
function body:isSitOnGround()return false end
function body:getSitOnFurnitureObject()return self.furniture end
function body:getBed()return self.bed end function body:setBed(value)self.bed=value end
function body:setBedType(value)self.bedType=value end
local active
ISTimedActionQueue={hasAction=function(action)return active==action end,queues={}}
local function action()
 local a={isValid=function()return true end,waitToStart=function(self)body.furniture=bed;return false end,
 start=function()body.onBed=true;body.vars.OnBedStarted=true;body.vars.OnBedAnim="Awake"end,
 update=function()end,perform=function(self)active=nil end,stop=function()end}
 function a:forceStop()self.stopped=true;active=nil;self:stop()end
 return a
end
ISGetOnBedAction={new=function()return action()end}
ISSitOnGround={new=function()return action()end}
SAO.Identity={get=function()return record end}
SAO.Needs={ownsRecoveryBody=function()return owned end,queueVerified=function(a)active=a;return true end}
SAO.History={countyHours=function()return 1 end}
SAOJavaBridge={recoveryBed=function()return available and bed or nil end,
 recoveryGroundClear=function()return clear end,isRecoveryPose=function()return poseSeen end}
local place={kind="bed",key="native-bed",x=10.5,y=20.5,z=0}
owned=false
check("foreign_begin_cannot_actuate",SAO.RecoveryPose.begin(body,"sleep","person",place)==nil and active==nil and body.furniture==nil)
owned=true;available=false
check("removed_bed_cannot_queue",SAO.RecoveryPose.begin(body,"sleep","person",place)==nil and active==nil)
available=true
local work=SAO.RecoveryPose.begin(body,"sleep","person",place)
check("selected_bed_queues_exact_action",work and active==work.action and work.bed==bed)
check("absent_installed_complete_is_empty_owned_callback",work.action:complete()==true and not work.finished and not body.onBed)
local other=setmetatable({vars={}}, {__index=body})
check("pending_bed_entry_is_exclusive",SAO.RecoveryPose.begin(other,"sleep","other",place)==nil and active==work.action)
work.action:waitToStart();available=false;work.action:start()
check("occupancy_race_blocks_start",work.cancelled and work.action.stopped and not body.onBed)
SAO.RecoveryPose.cancel(work)
available=true;body.furniture=nil
work=SAO.RecoveryPose.begin(body,"sleep","person",place)
check("cancelled_entry_releases_bed",work~=nil and SAO.RecoveryPose.bedUsers[bed]==work)
work.action:waitToStart();work.action:start();work.action:perform()
check("flag_without_pose_cannot_admit",SAO.RecoveryPose.poll(work)=="preparing" and body.bed==nil)
poseSeen=true
check("bed_pose_binds_native_quality",SAO.RecoveryPose.poll(work)=="preparing" and body.bed==bed and body.bedType=="goodBed" and body.vars.OnBedAnim=="Asleep")
check("native_sleep_pose_admits",SAO.RecoveryPose.poll(work)=="admitted")
SAO.RecoveryPose.cancel(work)
check("bed_cancel_yields_native_getup",body.bed==nil and body.vars.forceGetUp==true and body.onBed and body.furniture==bed)
check("retired_entry_releases_only_own_bed",SAO.RecoveryPose.bedUsers[bed]==nil)
body.onBed=false;body.furniture=nil;clear=false
local ground={kind="ground",key="ground:10:20:0",x=10.5,y=20.5,z=0}
check("ground_requires_actual_clearance",SAO.RecoveryPose.begin(body,"sleep","person",ground)==nil)
check("blocked_offset_cannot_move_body",SAO.RecoveryPose.setAppliedOffset(body,.4,.4)==false and body.x==10.5 and body.y==20.5)
clear=true;owned=false
check("foreign_offset_cannot_move_body",SAO.RecoveryPose.setAppliedOffset(body,.4,.4)==false and body.x==10.5)
owned=true
check("clear_owned_offset_moves_once",SAO.RecoveryPose.setAppliedOffset(body,.4,.4) and body.x==10.9 and body.y==20.9)
SAO.RecoveryPose.setAppliedOffset(body,.4,.4)
check("repeated_offset_does_not_accumulate",body.x==10.9 and body.y==20.9)
SAO.RecoveryPose.clearAppliedOffset(body)
check("offset_restored_once",body.x==10.5 and body.y==20.5)
-- Compare the owned methods to the installed action for every cardinal entry and route offset.
ISGetOnBedAction=nativeBedAction
local facing="E"
SeatingManager={getInstance=function()return {getFacingDirection=function()return facing end}end}
local physical="E"
local physicalBed={getX=function()return 10 end,getY=function()return 20 end,
 getProperties=function()return {get=function()return physical end}end}
local function probeBody(x,y)
 return {getX=function()return x end,getY=function()return y end,
 setVariable=function(self,k,v)self[k]=v end,
 faceLocationF=function(self,fx,fy)self.fx=fx;self.fy=fy end}
end
local approaches={
 N={{9.5,20.5},{11.5,20.5},{9.5,19.5},{11.5,19.5},{10.5,18.5}},
 S={{9.5,20.5},{11.5,20.5},{9.5,21.5},{11.5,21.5},{10.5,22.5}},
 W={{10.5,19.5},{10.5,21.5},{9.5,19.5},{9.5,21.5},{8.5,20.5}},
 E={{10.5,19.5},{10.5,21.5},{11.5,19.5},{11.5,21.5},{12.5,20.5}}}
for _,direction in ipairs({"N","S","W","E"}) do
 physical=direction;facing=direction
 for i,point in ipairs(approaches[direction]) do
  for _,offset in ipairs({-.3,0,.3}) do
   local x=point[1]+((direction=="N" or direction=="S") and 0 or offset)
   local y=point[2]+((direction=="N" or direction=="S") and offset or 0)
   local referenceBody=probeBody(x,y);local ownedBody=probeBody(x,y)
   local reference=nativeBedAction:new(referenceBody,physicalBed)
   local owned=SAO.RecoveryPose.newBedEntry(ownedBody,physicalBed)
   reference:setBeforeSitDirection();owned:setBeforeSitDirection()
   local before=referenceBody.fx==ownedBody.fx and referenceBody.fy==ownedBody.fy
     and referenceBody.OnBedDirection==ownedBody.OnBedDirection
   reference:setWhileSittingDirection();owned:setWhileSittingDirection()
   check("installed_direction_parity_"..direction.."_"..i.."_"..offset,
     before and referenceBody.fx==ownedBody.fx and referenceBody.fy==ownedBody.fy)
  end
 end
end
physical="E";facing="S"
local footBody=probeBody(11.5,21.5)
local entry=SAO.RecoveryPose.newBedEntry(footBody,physicalBed)
entry:setBeforeSitDirection()
local correct=footBody.OnBedDirection=="FootRight" and footBody.fx==11.5 and footBody.fy==18
entry:setWhileSittingDirection()
check("bed_direction_ignores_chair_position",correct and footBody.fx==13.5 and footBody.fy==21.5)
physical="invalid"
check("invalid_bed_direction_refused",SAO.RecoveryPose.newBedEntry(footBody,physicalBed)==nil)
__result="PASS recovery place Lua "..checks
