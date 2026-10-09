require 'KA_Core'
local K=KnoxAquarium
local function ensurePlacementClass()
    if KAPlacement then return KAPlacement end
    -- ISBuildingObject is loaded for gameplay, not while the main menu loads mods.
    if not ISBuildingObject then return nil end
    KAPlacement=ISBuildingObject:derive('KAPlacement')
    function KAPlacement:new(player,item,tier)
        local o={};setmetatable(o,self);self.__index=self;o:init()
        o.player=player:getPlayerNum();o.character=player;o.item=item
        o.nSprite=item and ((tonumber(item:getModData().KnoxAquariumRotation) or 0)%4+1) or 1
        -- Preview art follows the tier, so a large tank shows a large ghost.
        o.tier=tier or 'standard'
        local art=(K.tankTiers[o.tier] or K.tankTiers.standard).art..'empty'
        o:setSprite('media/textures/'..art..'.png')
        o:setNorthSprite('media/textures/KA_rot1/'..art..'.png')
        o:setEastSprite('media/textures/KA_rot2/'..art..'.png')
        o:setSouthSprite('media/textures/KA_rot3/'..art..'.png')
        o.dragNilAfterPlace=true;o.noNeedHammer=true
        return o
    end
    -- The facing the preview is showing, 0-3, in the same numbering the placed
    -- tank stores - so the preview and the tank agree on where it sits.
    function KAPlacement:facing()
        return math.max(0,math.min(3,(tonumber(self.nSprite) or 1)-1))
    end
    function KAPlacement:isValid(square)
        if self.item and not self.character:getInventory():contains(self.item) then return false end
        -- The whole tank (for the display tank that is two tiles), on a tile the
        -- player can WALK to: they go there first, as with vanilla furniture
        -- (K.walkThenPlace), and the full rule is checked again when they arrive.
        return K.canPlaceTankFrom(square,self.character,self.tier,self:facing()) and true or false
    end
    function KAPlacement:render(x,y,z,square)
        local path=self:getSprite();local texture=getTexture(path)
        if not texture or not texture:isReady() then return end
        if self.previewPath~=path then
            self.preview=IsoSprite.new();self.preview:LoadSingleTexture(path);self.previewPath=path
        end
        local valid=self:isValid(square)
        -- The same per-facing anchor the placed tank uses, so the ghost lands
        -- exactly where the tank will stand, against the same wall.
        local gx,gy=K.ghostOffsetsFor({tier=self.tier,rotation=self:facing()})
        self.preview:RenderGhostTileColor(x,y,z,gx,gy,valid and 1 or .8,valid and 1 or .2,valid and 1 or .2,.7)
    end
    function KAPlacement:tryBuild(x,y,z)
        local sq=getCell():getGridSquare(x,y,z)
        if not self:isValid(sq) then
            local _,why=K.canPlaceTankFrom(sq,self.character,self.tier,self:facing())
            self.character:Say((why and (why..' ') or 'Choose a clear tile. ')..K.rotateKeyName()..' rotates the preview.')
            return
        end
        getCell():setDrag(nil,self.player)
        K.walkThenPlace(self.character,sq,self.item,self.tier,self:facing())
    end
    function KAPlacement:rotateKey(key)
        if key==Keyboard.KEY_ESCAPE then getCell():setDrag(nil,self.player);return end
        ISBuildingObject.rotateKey(self,key)
    end
    return KAPlacement
end
K.ensurePlacementClass=ensurePlacementClass

-- Place a tank on `sq`, walking over first when the player is not already in
-- reach - how vanilla places furniture (ISBuildingObject.tryBuild -> walkTo ->
-- luautils.walkAdj -> ISWalkToTimedAction). Everything here is the CLIENT's
-- convenience: the command sent is exactly the one sent before, only from
-- closer, and the server checks it with the same rule it always has.
-- Returns 'now', 'walk', or nil when nothing happened (the reason is said).
function K.walkThenPlace(character,sq,item,tier,facing)
    local command=item and 'placeKit' or 'place'
    local function place()
        -- a kit dropped or used on the way is not placed
        if item and not character:getInventory():contains(item) then return end
        local ok,why=K.canPlaceTank(sq,character,tier,facing)
        if not ok then character:Say(why or 'Cannot place it there.'); return end
        K.send(character,command,sq,item,tier,facing)
    end
    -- In reach already - the placement that was tested live in multiplayer -
    -- goes straight through, with no walking.
    if K.canPlaceTank(sq,character,tier,facing) then place(); return 'now' end
    if not (AdjacentFreeTileFinder and ISWalkToTimedAction and ISTimedActionQueue) then
        character:Say('Stand closer to where you want it.')
        return nil
    end
    -- Never stop on the tank's own second tile: the tank could not go down
    -- with the player standing in it.
    local exclude={}
    local second=K.partSquare({tier=tier,rotation=facing},sq)
    if second then exclude[1]=second end
    local adjacent=AdjacentFreeTileFinder.Find(sq,character,exclude)
    if not adjacent then
        character:Say("You can't get to that spot.")
        return nil
    end
    local walk=ISWalkToTimedAction:new(character,adjacent)
    walk:setOnComplete(place)
    ISTimedActionQueue.clear(character)
    ISTimedActionQueue.add(walk)
    return 'walk'
end
function K.startPlacement(player,item,tier)
    local cursor=ensurePlacementClass()
    if not cursor then player:Say('Aquarium placement is available after your game has finished loading.');return end
    getCell():setDrag(cursor:new(player,item,tier),player:getPlayerNum())
    player:Say('Aquarium placement: '..K.rotateKeyName()..' rotates; click a clear tile and you walk over to it; Escape cancels.')
end
Events.OnFillInventoryObjectContextMenu.Add(function(index,context,items)
    local player=getSpecificPlayer(index)
    for _,entry in ipairs(items) do
        local item=entry
        if not instanceof(entry,'InventoryItem') then item=entry.items and entry.items[1] end
        if item then
            -- Every tier's kit item places that tier's tank.
            for id,tier in pairs(K.tankTiers) do
                if tier.item and item:getFullType()==tier.item then
                    context:addOption('Place '..string.lower(tier.label)..' ('..K.rotateKeyName()..' to rotate)',player,
                        function(p) K.startPlacement(p,item,id) end)
                    return
                end
            end
        end
    end
end)
