__sourceActive=true
__queueActive=true
__npcLease=false
__headphones=true
__power=true
__mainPresent=true
__leftPresent=true
__rightPresent=true
__volume=0.61
__slotCurrent=true
__playerDead=false
__playerAsleep=false
__playerSquare=nil
__overlayFailure=false
__queueReset=0
__queueComplete=0
__xpCount=0
__moodCount=0
__overlayCount=0
__overlayDestroyed=0
__sounds={}
__nextSound=0
__soundPlaying={}
__queuedAction=nil
__tracks={{mode="slow",sound="slow1",length=215},
    {mode="medium",sound="medium1",length=211},
    {mode="fast",sound="fast1",length=230}}

SAO={SourceIntegration={active=function(id)
    assert(id=="LifestyleHobbies")
    return __sourceActive
end},LeisureLifestyle={physicalSourceOwner=function(booth)
    return __npcLease and booth==__booth
end}}
require=function(name)
    if name=="SAO_SourceIntegration" then return SAO.SourceIntegration end
    if name=="TimedActions/ISBaseTimedAction" then return ISBaseTimedAction end
    if name=="TimedActions/PlayDJBoothTracks" then return __tracks end
    if name=="ISBaseObject" then return ISBaseObject end
    error("unexpected require "..tostring(name))
end
DJBoothMenu={playerQueueOwner=function(booth,action)
    return booth==__booth and action==__queuedAction and __queueActive
end}
CharacterTrait={DEAF="DEAF",VIRTUOSO="VIRTUOSO",KEEN_HEARING="KEEN_HEARING",
    HARD_OF_HEARING="HARD_OF_HEARING",TONEDEAF="TONEDEAF",
    DESENSITIZED="DESENSITIZED",BRAVE="BRAVE",DISCIPLINED="DISCIPLINED",
    DEXTROUS="DEXTROUS",CLUMSY="CLUMSY"}
Perks={Music="Music"}
MoodleType={PANIC="PANIC"}
Keyboard={KEY_E="E",KEY_C="C",KEY_A="A",KEY_S="S",KEY_W="W",KEY_D="D",
    KEY_UP="UP",KEY_DOWN="DOWN",KEY_LEFT="LEFT",KEY_RIGHT="RIGHT"}
isKeyDown=function(key)return __pressed and __pressed[key] or false end
SandboxVars={ElecShutModifier=2,Music={StrengthMultiplier=2}}
GameTime={getInstance=function()
    return{getNightsSurvived=function()return __nights end}
end}
getGameTime=function()return{getGameWorldSecondsSinceLastUpdate=function()return 0 end}end
GTLSCheck=1
ZombRand=function(a,b)if b then return a end;return 0 end
getText=function(key)return key end
HaloTextHelper={addTextWithArrow=function()end}
LSUtil={getCharacterMood=function(_,name)
    return ({Stress=0.1,Endurance=0.8,Fatigue=0.1})[name] or 0
end,changeCharacterMoodGroup=function(actor,group)
    assert(actor==__player and group.Boredom and group.Stress)
    __moodCount=__moodCount+1
end}
sendClientCommand=function(actor,channel,command,args)
    assert(actor==__player and channel=="LS" and command=="AddXP" and args[1]=="Music")
    __xpCount=__xpCount+1
end
local manager={getMusicVolume=function()return __volume end,
    setMusicVolume=function(_,volume)__volume=volume end,
    PlayWorldSound=function(_,sound)__sounds[#__sounds+1]=sound end}
getSoundManager=function()return manager end
addSound=function()__worldSoundCount=(__worldSoundCount or 0)+1 end
LS_DJBooth={keyPress=function()__keyClose=(__keyClose or 0)+1 end}
DJSoundboardOverlay={new=function()
    if __overlayFailure then error("controlled overlay failure") end
    __overlayCount=__overlayCount+1
    return{initialise=function()end,addToUIManager=function()end,
        destroy=function()__overlayDestroyed=__overlayDestroyed+1 end}
end}
ISTimedActionQueue={getTimedActionQueue=function()
    return{resetQueue=function()__queueReset=__queueReset+1;__queueActive=false end,
        onCompleted=function(_,action)
            assert(action==__queuedAction)
            __queueComplete=__queueComplete+1;__queueActive=false
        end}
end}
ISLogSystem={logAction=function()end}

local function objects(rows)
    return{size=function()return #rows end,get=function(_,index)return rows[index+1]end}
end
local function properties()
    return{has=function(_,key)return key=="CustomName" or key=="Facing" end,
        get=function(_,key)
            if key=="CustomName" then return "Booth" end
            if key=="Facing" then return "S" end
        end}
end
local function object(name,square,x,y)
    return{getSprite=function()return{getName=function()return name end,
        getProperties=properties}end,
        getSquare=function()return square end,getX=function()return x end,
        getY=function()return y end,getZ=function()return 0 end}
end
local front={getX=function()return 10 end,getY=function()return 11 end,
    getZ=function()return 0 end}
local mainSquare={haveElectricity=function()return __power end,
    getS=function()return front end}
local leftSquare,rightSquare={},{}
__booth=object("ls_djbooth_01_1",mainSquare,10,10)
__left=object("ls_djbooth_01_0",leftSquare,9,10)
__right=object("ls_djbooth_01_2",rightSquare,11,10)
mainSquare.getObjects=function()return objects(__mainPresent and {__booth} or {})end
leftSquare.getObjects=function()return objects(__leftPresent and {__left} or {})end
rightSquare.getObjects=function()return objects(__rightPresent and {__right} or {})end
getCell=function()return{getGridSquare=function(_,x,y,z)
    if y~=10 or z~=0 then return nil end
    if x==10 then return mainSquare end
    if x==9 then return leftSquare end
    if x==11 then return rightSquare end
end}end
__playerSquare=front
local data={LSMoodles={DJAudience={Value=0},PartyGood={Value=0},
    PartyBad={Value=0},Embarrassed={Value=0}}}
local headphone={getType=function()return "Authentic_Headphones4" end}
local emitter={playSound=function(_,sound)
    __nextSound=__nextSound+1
    __sounds[#__sounds+1]=sound
    __soundPlaying[__nextSound]=true
    return __nextSound
end,isPlaying=function(_,handle)return __soundPlaying[handle]==true end,
    stopSound=function(_,handle)__soundPlaying[handle]=false end}
__player={getPlayerNum=function()return 0 end,
    isDead=function()return __playerDead end,isAsleep=function()return __playerAsleep end,
    isExistInTheWorld=function()return true end,
    getVehicle=function()return nil end,isSitOnGround=function()return false end,
    isSneaking=function()return false end,hasTrait=function()return false end,
    getSquare=function()return __playerSquare end,
    getInventory=function()return{getItems=function()
        return objects(__headphones and {headphone} or {})
    end}end,isEquippedClothing=function(_,item)return item==headphone and __headphones end,
    getPerkLevel=function()return __level end,
    getModData=function()return data end,
    getX=function()return 10 end,getY=function()return 11 end,getZ=function()return 0 end,
    setX=function()end,setY=function()end,
    getEmitter=function()return emitter end,isTimedActionInstant=function()return false end,
    isOutside=function()return false end,
    getMoodles=function()return{getMoodleLevel=function()return 0 end}end,
    setIsFarming=function()end,setTimedActionToRetrigger=function()end,
    faceThisObject=function()end,shouldBeTurning=function()return false end}
getSpecificPlayer=function(index)
    assert(index==0)
    return __slotCurrent and __player or {}
end
function __fresh()
    __sourceActive=true;__queueActive=true;__npcLease=false;__headphones=true
    __power=true;__mainPresent=true;__leftPresent=true;__rightPresent=true
    __volume=0.61;__slotCurrent=true;__playerDead=false;__playerAsleep=false
    __playerSquare=front;__overlayFailure=false;__queueReset=0;__queueComplete=0
    __xpCount=0;__moodCount=0;__overlayCount=0;__overlayDestroyed=0
    __sounds={};__nextSound=0;__soundPlaying={};__queuedAction=nil
    __worldSoundCount=0;__keyClose=0;__level=0;__nights=1;__pressed={}
    data.PlayingInstrument=false;data.LSMoodles.Embarrassed.Value=0
    LS_DJBooth.isPlaying=false;LS_DJBooth.isPlayingMic=false;LS_DJBooth.failstate=false
end
function __make(mode,sound)
    local action=PlayDJBoothAction:new(__player,__booth,sound or "slow1",mode or "slow",
        1,999,999,999,"Bob_PlayDJDefault",false)
    action.action={forceStop=function()action:stop()end,
        setUseProgressBar=function()end,setActionAnim=function()end,
        setOverrideHandModelsObject=function()end,
        isStarted=function()return action.saoStarted end}
    __queuedAction=action;__queueActive=true
    return action
end
