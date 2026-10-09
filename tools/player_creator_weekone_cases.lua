-- Loaded after mod-patches' Week One fixture and selected native method.
-- The final NEXT executes the actual P005 wrapper and SAO Creator modules.
Events.OnCreatePlayer = {Add=function() end,Remove=function() end}
Events.LoadGridsquare = {Add=function() end}
local world = getWorld()
world.getGameMode = function() return "Sandbox" end
SandboxVars.SurvivorAwareness = {WeekOneNuke=false}
SandboxVars.BanditsWeekOne.StartBabe = true
SandboxVars.BanditsWeekOne.EventFinalSolution = true
MainScreen.instance.charCreationMain.forenameEntry =
    {getText=function() return "Avery" end}
MainScreen.instance.charCreationMain.surnameEntry =
    {getText=function() return "Stone" end}
function MainScreen.instance:addChild(child)
    if child.createChildren then child:createChildren() end
end
function MainScreen.instance:removeChild() end
local nativeCore = getCore()
nativeCore.getScreenWidth = function() return 1280 end
nativeCore.getScreenHeight = function() return 800 end
nativeCore.getAccountUsed = function()
    return {getUserName=function() return "PlayerOne" end}
end
MainScreen.instance.desc = {getID=function() return 101 end}
SAO.History = {countyHours=function() return 3 end}
SAO.Log = {line=function() end}
SAO.Identity = {idByName=function() return nil end}
local stores = {}
ModData = {
    getOrCreate=function(key)
        stores[key]=stores[key] or {}
        return stores[key]
    end,
    get=function(key) return stores[key] end,
}

ISPanelJoypad = {}
function ISPanelJoypad:derive()
    local child={}
    setmetatable(child,{__index=self})
    return child
end
function ISPanelJoypad:new(x,y,width,height)
    local item={x=x,y=y,width=width,height=height,children={}}
    setmetatable(item,{__index=self})
    return item
end
function ISPanelJoypad:initialise() end
function ISPanelJoypad:addChild(child)
    self.children[#self.children+1]=child
    if child.createChildren then child:createChildren() end
end
function ISPanelJoypad:setVisible(value) self.visible=value end
function ISPanelJoypad:prerender() end
ISButton={}
function ISButton:new(x,y,width,height,title,owner,onclick)
    return setmetatable({x=x,y=y,width=width,height=height,title=title,
        owner=owner,onclick=onclick},{__index=self})
end
function ISButton:initialise() end
function ISButton:instantiate() end
function ISButton:setVisible(value) self.visible=value end
function ISButton:setTitle(value) self.title=value end
ISTextEntryBox={}
function ISTextEntryBox:new(value,x,y,width,height)
    return setmetatable({text=value,x=x,y=y,width=width,height=height},
        {__index=self})
end
function ISTextEntryBox:initialise() end
function ISTextEntryBox:instantiate() end
function ISTextEntryBox:getText() return self.text end
function ISTextEntryBox:setText(value) self.text=value end
function ISTextEntryBox:setMultipleLine() end
function ISTextEntryBox:setMaxLines() end
function ISTextEntryBox:setVisible(value) self.visible=value end

local function body()
    local desc={
        getForename=function() return "Avery" end,
        getSurname=function() return "Stone" end,
        getID=function() return 101 end,
        getCharacterProfession=function()
            return {getName=function() return "firefighter" end}
        end,
    }
    local nativeSquare={getX=function() return 10 end,
        getY=function() return 20 end,getZ=function() return 0 end}
    return {data={},
        getModData=function(self) return self.data end,
        getDescriptor=function() return desc end,
        getUsername=function() return "PlayerOne" end,
        isDead=function() return false end,
        getCurrentSquare=function() return nativeSquare end}
end

function fixtureCrossRepo()
    local checks={}
    local function check(name,value)
        if not value then checks[#checks+1]=name end
    end
    local panel={
        variantListBox={selected=3},
        disableBtn=function(self) self.disabled=true end,
        setVisible=function(self,value) self.visible=value end,
    }
    VariantMain.onOptionMouseDown(panel,{internal="NEXT"})
    local creator=SAO.Creator.UI.active
    check("creator-before-transition", creator~=nil and created==0
        and forced==0 and rendered==0)
    if not creator then return table.concat(checks,",") end
    creator.groupEntry:setText("Old friends")
    creator.backgroundEntry:setText(
        "A firefighter who returned home before the outbreak.")
    creator:onClick(creator.noneButton)
    creator:onClick(creator.continueButton)
    check("native-selected-variant", created==1
        and SandboxVars.BanditsWeekOne.Variant==3
        and createdName=="selected-save")
    check("native-transition-exact-once", forced==1
        and rendered==1 and panel.disabled==true)
    check("explicit-off-suppresses-default",
        SandboxVars.BanditsWeekOne.EventFinalSolution==false
        and SandboxVars.SurvivorAwareness.WeekOneNuke==false)
    local player=body()
    local creatorKey="player:PlayerOne/character/sao-player-1"
    local nativeJoin=SAO.Standing.joinGroup
    SAO.Standing.joinGroup=function(key, name)
        nativeJoin(key, name)
        return false
    end
    local applied, refusal=SAO.Creator.onCreatePlayer(0,player)
    check("production-group-refusal-has-no-world-choice", applied==false
        and refusal=="group-owner-refused"
        and player.data.SAOCreationReceipt==nil
        and SAO.Standing.groupOf(creatorKey)==nil
        and (not stores.SurvivorAwareness_Nuke
            or not stores.SurvivorAwareness_Nuke.creatorChoice)
        and stores.SurvivorAwareness_PlayerCreator.nextCharacter==1)
    SAO.Standing.joinGroup=nativeJoin
    local nukeStore=stores.SurvivorAwareness_Nuke or {}
    stores.SurvivorAwareness_Nuke=nukeStore
    nukeStore.producer="SAO"
    applied, refusal=SAO.Creator.onCreatePlayer(0,player)
    check("production-nuke-refusal-rolls-back-group", applied==false
        and refusal=="nuke-owner-refused"
        and player.data.SAOCreationReceipt==nil
        and SAO.Standing.groupOf(creatorKey)==nil
        and nukeStore.producer=="SAO"
        and stores.SurvivorAwareness_PlayerCreator.nextCharacter==1)
    nukeStore.producer="none"
    nukeStore.creatorChoice={schema="sao-created-player/1",
        decisionId=world:getWorld().."|Sandbox|1",world=world:getWorld(),
        gameMode="Sandbox",characterId="sao-player-1",
        playerKey=creatorKey,nativeDescriptorId=202,
        appliedAtHours=3,nukeChoice="none"}
    applied, refusal=SAO.Creator.onCreatePlayer(0,player)
    check("seeded-foreign-descriptor-refuses-native-creator",
        applied==false and refusal=="nuke-owner-refused"
        and player.data.SAOCreationReceipt==nil
        and SAO.Standing.groupOf(creatorKey)==nil
        and nukeStore.creatorChoice.nativeDescriptorId==202
        and stores.SurvivorAwareness_PlayerCreator.nextCharacter==1)
    nukeStore.creatorChoice=nil
    nukeStore.producer=nil
    applied=SAO.Creator.onCreatePlayer(0,player)
    if not applied then return table.concat(checks,",") end
    local receipt=player.data.SAOCreationReceipt
    check("native-application-receipt", applied==true and receipt
        and receipt.weekOneVariant==3 and receipt.weekOneStartBabe==true
        and receipt.nukeChoice=="none"
        and receipt.nativeDescriptorId==101
        and receipt.accountKey=="player:PlayerOne"
        and receipt.playerKey=="player:PlayerOne/character/sao-player-1"
        and receipt.groupName=="Old friends")
    check("production-standing-character-group",
        SAO.Standing.playerKey(player)==receipt.playerKey
        and SAO.Standing.groupOf(receipt.playerKey)=="Old friends")
    getSpecificPlayer=function(slot) return slot==0 and player or nil end
    local marked=SAO.PlayerObjectives.mark(player,
        {getX=function() return 22 end,getY=function() return 20 end,
            getZ=function() return 0 end})
    check("objective-bound-to-created-character",
        marked=="square 22,20,0"
        and SAO.PlayerObjectives.marks[receipt.playerKey].x==22
        and SAO.PlayerObjectives.marks[receipt.accountKey]==nil)
    check("owner-and-world-persistence",
        stores.SurvivorAwareness_Nuke
        and stores.SurvivorAwareness_Nuke.producer=="none"
        and stores.SurvivorAwareness_Nuke.creatorChoice
        and stores.SurvivorAwareness_Nuke.creatorChoice.playerKey
            ==receipt.playerKey
        and stores.SurvivorAwareness_PlayerCreator
        and stores.SurvivorAwareness_PlayerCreator
            .characters["sao-player-1"]~=nil)
    SandboxVars.BanditsWeekOne.EventFinalSolution=true
    check("world-owner-survives-external-toggle",
        SAO.Nuke.effectiveProducer()=="none")
    return table.concat(checks,",")
end
