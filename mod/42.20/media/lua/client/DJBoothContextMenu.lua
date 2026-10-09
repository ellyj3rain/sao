-- SAO player DJ menu. The selected Lifestyle source and terms remain in SAOSources.
-- Its booth art, sounds, translation keys and native timed action stay available;
-- this menu owns selection, live admission and the player's explicit choice.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end

local PlayDJBoothAction = require "TimedActions/PlayDJBoothAction"
local tracks = require "TimedActions/PlayDJBoothTracks"
local trackModes = {
    slow = {text="ContextMenu_Play_DJBooth_Slow", icon="media/ui/fire_icon.png"},
    medium = {text="ContextMenu_Play_DJBooth_Medium", icon="media/ui/fire2_icon.png",
        deniedIcon="media/ui/fire2No_icon.png", deniedText="ContextMenu_Play_DJBooth_MediumNo", level=3},
    fast = {text="ContextMenu_Play_DJBooth_Fast", icon="media/ui/fire3_icon.png",
        deniedIcon="media/ui/fire3No_icon.png", deniedText="ContextMenu_Play_DJBooth_FastNo", level=6},
    housemix = {text="ContextMenu_Play_DJBooth_HouseMix", icon="media/ui/addon_icon.png"},
}
local modeOrder = {"slow", "medium", "fast", "housemix"}
local headphones = {
    Hat_EarMuff_Protectors=true, Hat_EarMuff_Protectors_Neck=true,
    Hat_EarMuff_Protectors_AZ=true, Authentic_Headphones=true,
    Authentic_Headphones2=true, Authentic_Headphones3=true,
    Authentic_Headphones4=true, Authentic_HeadphonesNeck=true,
    Authentic_HeadphonesNeck2=true, Authentic_HeadphonesNeck3=true,
    Authentic_HeadphonesNeck4=true,
}
local function tracksFor(mode)
    local choices={}
    if not trackModes[mode] then return choices end
    for _,track in ipairs(tracks) do
        if track.mode==mode and type(track.sound)=="string"
            and type(track.length)=="number" and track.length>0 then
            choices[#choices+1]=track
        end
    end
    return choices
end

DJBoothMenu = DJBoothMenu or {}
local M = DJBoothMenu
local pending = {}

function M.playerQueueOwner(booth,action)
    -- The native timed-action queue is authoritative. A cancelled walk or DJ
    -- action releases this exact claim on the next inquiry.
    for object,action in pairs(pending) do
        local ok,queued=pcall(ISTimedActionQueue.hasAction,action)
        if not ok or not queued then pending[object]=nil end
    end
    if not booth then return false end
    if action then return pending[booth]==action end
    return pending[booth]~=nil
end

local function spriteName(object)
    local sprite = object and object:getSprite()
    local properties = sprite and sprite:getProperties()
    if not properties or not properties:has("CustomName")
        or properties:get("CustomName")~="Booth" then return nil end
    return sprite:getName()
end

local function squareContains(square, object)
    local objects = square and square:getObjects()
    if not objects then return false end
    for i=0,objects:size()-1 do
        if objects:get(i)==object then return true end
    end
    return false
end

local function assembled(booth)
    local square = booth and booth:getSquare()
    if not square or not squareContains(square,booth) then return false end
    local name = spriteName(booth)
    if name~="ls_djbooth_01_1" and name~="ls_djbooth_01_4" then return false end
    local cell = getCell()
    if not cell then return false end
    local left,right = false,false
    for x=booth:getX()-1,booth:getX()+1 do
        for y=booth:getY()-1,booth:getY()+1 do
            local nearby = cell:getGridSquare(x,y,booth:getZ())
            local objects = nearby and nearby:getObjects()
            if objects then
                for i=0,objects:size()-1 do
                    local side = spriteName(objects:get(i))
                    if side=="ls_djbooth_01_0" or side=="ls_djbooth_01_3" then left=true end
                    if side=="ls_djbooth_01_2" or side=="ls_djbooth_01_5" then right=true end
                end
            end
        end
    end
    return left and right
end

local function powered(booth)
    local square = booth and booth:getSquare()
    if not square then return false end
    local cutoff = SandboxVars and SandboxVars.ElecShutModifier
    return (type(cutoff)=="number" and cutoff>-1
        and GameTime:getInstance():getNightsSurvived()<cutoff)
        or square:haveElectricity()
end

local function equippedHeadphones(player)
    local inventory = player:getInventory()
    local items = inventory and inventory:getItems()
    if not items then return false end
    for i=0,items:size()-1 do
        local item=items:get(i)
        if item and headphones[item:getType()] and player:isEquippedClothing(item) then return true end
    end
    return false
end

local function embarrassed(player)
    local data=player:getModData()
    local mood=data and data.LSMoodles and data.LSMoodles.Embarrassed
    return mood and type(mood.Value)=="number" and mood.Value>=0.2
end

local function playerReady(player)
    local playerIndex=player and player:getPlayerNum()
    return type(playerIndex)=="number" and getSpecificPlayer(playerIndex)==player
        and not player:getVehicle() and not player:isSitOnGround()
        and not player:isSneaking() and not player:hasTrait(CharacterTrait.DEAF)
end

local function stationOwned(booth)
    local lifestyle=SAO and SAO.LeisureLifestyle
    return lifestyle and type(lifestyle.physicalSourceOwner)=="function"
        and lifestyle.physicalSourceOwner(booth)==true
end

local function stationBusy(booth)
    return stationOwned(booth) or M.playerQueueOwner(booth) or (type(LS_DJBooth)=="table"
        and (LS_DJBooth.isPlaying==true or LS_DJBooth.isPlayingMic==true))
end

local function canStart(player,booth,mode)
    local config=trackModes[mode]
    return config and playerReady(player) and assembled(booth) and powered(booth)
        and equippedHeadphones(player) and not embarrassed(player)
        and player:getPerkLevel(Perks.Music)>=(config.level or 0)
        and not stationBusy(booth)
end

local function reductions(player)
    local level=player:getPerkLevel(Perks.Music)
    local xp=level>=10 and 0 or 0.01*(level+1)
    if level<10 then
        if player:hasTrait(CharacterTrait.TONEDEAF) then xp=xp*0.2
        elseif player:hasTrait(CharacterTrait.HARD_OF_HEARING) then xp=xp*0.6 end
    end
    local boredom,stress=0.12*(level+1),0.001*(level+1)
    if player:hasTrait(CharacterTrait.VIRTUOSO) then
        boredom,stress=boredom*3,stress*3
    elseif player:hasTrait(CharacterTrait.KEEN_HEARING) then
        boredom,stress=boredom*2,stress*2
    elseif player:hasTrait(CharacterTrait.TONEDEAF) then
        boredom,stress=-0.24/(level+1),-0.002/(level+1)
    elseif player:hasTrait(CharacterTrait.HARD_OF_HEARING) then
        boredom,stress=-0.12/(level+1),-0.001/(level+1)
    end
    return xp,boredom,stress
end

local function tooltip(option,message)
    option.notAvailable=true
    local tip=ISToolTip:new()
    tip:initialise()
    tip:setVisible(false)
    tip.description=" <RED>"..getText(message)
    option.toolTip=tip
end

function M.onEnableDancing(_,player)
    player:getModData().WantsToDance=true
end

function M.onDisableDancing(_,player)
    player:getModData().WantsToDance=false
end

function M.walkToFront(player,booth)
    if not assembled(booth) then return false end
    local sprite=booth:getSprite()
    local properties=sprite and sprite:getProperties()
    local facing=properties and properties:has("Facing") and properties:get("Facing")
    local square=booth:getSquare()
    local frontSquare
    if facing=="S" then frontSquare=square:getS()
    elseif facing=="E" then frontSquare=square:getE()
    elseif facing=="W" then frontSquare=square:getW()
    elseif facing=="N" then frontSquare=square:getN() end
    if not frontSquare or not AdjacentFreeTileFinder.privTrySquare(square,frontSquare) then return false end
    ISTimedActionQueue.add(ISWalkToTimedAction:new(player,frontSquare))
    return true
end

function M.onPlay(_,player,booth,sound,mode)
    if not canStart(player,booth,mode) then return false end
    local chosen
    for _,track in ipairs(tracksFor(mode)) do
        if track.sound==sound then chosen=track;break end
    end
    if not chosen or not M.walkToFront(player,booth) then return false end
    local xp,boredom,stress=reductions(player)
    local action=PlayDJBoothAction:new(player,booth,chosen.sound,mode,
        chosen.length*48,xp,boredom,stress,"Bob_PlayDJDefault",false)
    pending[booth]=action
    ISTimedActionQueue.add(action)
    local ok,queued=pcall(ISTimedActionQueue.hasAction,action)
    if not ok or not queued then pending[booth]=nil;return false end
    -- The default is recorded only after an explicit accepted action. Opening
    -- a menu or losing its queue admission does not alter the saved choice.
    local data=player:getModData()
    if data and data.WantsToDance==nil then data.WantsToDance=true end
    return true
end

function M.doBuildMenu(playerIndex,context,worldobjects)
    local player=getSpecificPlayer(playerIndex)
    if not playerReady(player) then return end
    local booth
    for _,object in ipairs(worldobjects) do
        local square=object:getSquare()
        local objects=square and square:getObjects()
        if objects then
            for i=0,objects:size()-1 do
                local candidate=objects:get(i)
                if assembled(candidate) then booth=candidate;break end
            end
        end
        if booth then break end
    end
    if not booth or not powered(booth) then return end

    local wants=player:getModData().WantsToDance
    if wants==false then
        local option=context:addOption(getText("ContextMenu_DancingPartner_Enable_Option"),
            worldobjects,M.onEnableDancing,player)
        option.iconTexture=getTexture("media/ui/okay_icon.png")
    elseif wants==true then
        local option=context:addOption(getText("ContextMenu_DancingPartner_Disable_Option"),
            worldobjects,M.onDisableDancing,player)
        option.iconTexture=getTexture("media/ui/okayNo_icon.png")
    end

    local parent=context:addOption(getText("ContextMenu_Play_DJBooth"))
    if not equippedHeadphones(player) then
        tooltip(parent,"ContextMenu_Play_DJBooth_NoHeadPhone")
        parent.iconTexture=getTexture("media/ui/djboothNo_icon.png")
        return
    elseif embarrassed(player) then
        tooltip(parent,"ContextMenu_Embarrassed")
        parent.iconTexture=getTexture("media/ui/djboothNo_icon.png")
        return
    elseif stationBusy(booth) then
        parent.notAvailable=true
        parent.iconTexture=getTexture("media/ui/djboothNo_icon.png")
        return
    end
    parent.iconTexture=getTexture("media/ui/djbooth_icon.png")
    local submenu=ISContextMenu:getNew(context)
    context:addSubMenu(parent,submenu)
    for _,mode in ipairs(modeOrder) do
        local choices=tracksFor(mode)
        if #choices>0 then
            local config=trackModes[mode]
            local track=choices[ZombRand(#choices)+1]
            local option=submenu:addOption(getText(config.text),worldobjects,M.onPlay,
                player,booth,track.sound,mode)
            if player:getPerkLevel(Perks.Music)<(config.level or 0) then
                tooltip(option,config.deniedText)
                option.iconTexture=getTexture(config.deniedIcon)
            else
                option.iconTexture=getTexture(config.icon)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(M.doBuildMenu)
