__active=true
__ownedObject=nil
__queued={}
__queueRefusal=false
__mainPresent=true
__leftPresent=true
__rightPresent=true
__power=true
__headphones=true
__frontFree=true
__nights=1
__cutoff=2
__level=0
__slotCurrent=true
__registered=nil
__tracks={{mode="slow",sound="slow1",length=215},
    {mode="medium",sound="medium1",length=211},
    {mode="fast",sound="fast1",length=230}}

SAO={SourceIntegration={active=function(id)
    assert(id=="LifestyleHobbies")
    return __active
end},LeisureLifestyle={physicalSourceOwner=function(object)
    return object==__ownedObject
end}}
require=function(name)
    if name=="SAO_SourceIntegration" then return SAO.SourceIntegration end
    if name=="TimedActions/PlayDJBoothTracks" then
        return __tracks
    end
    if name=="TimedActions/PlayDJBoothAction" then
        return {new=function(_,...)return{kind="dj",args={...}}end}
    end
    error("unexpected require "..tostring(name))
end
Events={OnFillWorldObjectContextMenu={Add=function(fn)__registered=fn end}}
CharacterTrait={DEAF="DEAF",VIRTUOSO="VIRTUOSO",TONEDEAF="TONEDEAF",
    HARD_OF_HEARING="HARD_OF_HEARING",KEEN_HEARING="KEEN_HEARING"}
Perks={Music="Music"}
SandboxVars={ElecShutModifier=2}
GameTime={getInstance=function()return{getNightsSurvived=function()return __nights end}end}
getText=function(key)return key end
getTexture=function(key)return key end
ZombRand=function(n)assert(n>0);return 0 end
ISToolTip={new=function()return{initialise=function()end,setVisible=function()end}end}
ISTimedActionQueue={add=function(action)
    if __queueRefusal and action.kind=="dj" then return end
    __queued[#__queued+1]=action
end,hasAction=function(action)
    for _,queued in ipairs(__queued)do if queued==action then return true end end
    return false
end}
ISWalkToTimedAction={new=function(_,player,square)return{kind="walk",player=player,square=square}end}
AdjacentFreeTileFinder={privTrySquare=function()return __frontFree end}

local function props(name)
    return{has=function(_,key)return key=="CustomName" or key=="Facing" end,
        get=function(_,key)return key=="CustomName" and "Booth" or key=="Facing" and "S" end}
end
local function sprite(name)
    return{getName=function()return name end,getProperties=function()return props(name)end}
end
local front={label="front"}
local mainSquare={haveElectricity=function()return __power end,getS=function()return front end}
local leftSquare,rightSquare={},{}
local function objects(rows)
    return{size=function()return #rows end,get=function(_,index)return rows[index+1]end}
end
local function object(name,square,x,y)
    return{getSprite=function()return sprite(name)end,
        getSquare=function()return square end,getX=function()return x end,
        getY=function()return y end,getZ=function()return 0 end}
end
__booth=object("ls_djbooth_01_1",mainSquare,10,10)
__left=object("ls_djbooth_01_0",leftSquare,9,10)
__right=object("ls_djbooth_01_2",rightSquare,11,10)
mainSquare.getObjects=function()return objects(__mainPresent and {__booth} or {})end
leftSquare.getObjects=function()return objects(__leftPresent and {__left} or {})end
rightSquare.getObjects=function()return objects(__rightPresent and {__right} or {})end
getCell=function()return{getGridSquare=function(_,x,y,z)
    if z~=0 or y~=10 then return nil end
    if x==10 then return mainSquare end
    if x==9 then return leftSquare end
    if x==11 then return rightSquare end
end}end

local data={LSMoodles={Embarrassed={Value=0}}}
local headphone={getType=function()return"Authentic_Headphones4"end}
__player={getVehicle=function()return nil end,isSitOnGround=function()return false end,
    getPlayerNum=function()return 0 end,
    isSneaking=function()return false end,hasTrait=function(_,trait)return __traits and __traits[trait] or false end,
    getModData=function()return data end,
    getInventory=function()return{getItems=function()
        return objects(__headphones and {headphone} or {})
    end}end,isEquippedClothing=function(_,item)return item==headphone and __headphones end,
    getPerkLevel=function()return __level end}
getSpecificPlayer=function(index)assert(index==0);return __slotCurrent and __player or {} end
LS_DJBooth={}

ISContextMenu={getNew=function()
    return{options={},addOption=function(self,name,...)
        local option={name=name,args={...}}
        self.options[#self.options+1]=option
        return option
    end}
end}
function __context()
    return{options={},addOption=ISContextMenu.getNew().addOption,
        addSubMenu=function(_,option,submenu)option.submenu=submenu end}
end
function __fresh()
    __active=true;__ownedObject=nil;__queued={};__queueRefusal=false;__mainPresent=true
    __leftPresent=true;__rightPresent=true;__power=true;__headphones=true
    __frontFree=true;__nights=1;__level=0;__slotCurrent=true;__traits=nil
    data.WantsToDance=nil;data.LSMoodles.Embarrassed.Value=0
    LS_DJBooth.isPlaying=false;LS_DJBooth.isPlayingMic=false
    SandboxVars.ElecShutModifier=2
end
function __menu()
    local context=__context()
    assert(__registered)
    __registered(0,context,{__booth})
    return context
end
function __option(menu,key)
    for _,row in ipairs(menu.options)do
        if row.name==key then return row end
    end
end
function __play(option)
    assert(option)
    local args=option.args
    return args[2](args[1],args[3],args[4],args[5],args[6])
end
