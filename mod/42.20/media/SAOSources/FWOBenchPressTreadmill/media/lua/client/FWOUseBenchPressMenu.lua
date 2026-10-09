--[[
    FWO Working Bench Press - Context Menu
    Build 42

    Adds benchpress exercise option to context menu
]]

local FWOUseBenchPressMenu = {}

-- Per-player facing state (indexed by player number, NOT global) — prevents
-- local co-op / split-screen players from clobbering each other's facing
-- while building context menus on the same client.
local FWOFacingByPlayer = {}

-- These are the walkable/front halves of the multi-tile bench. They should be
-- selectable by the player, but they are not the controller object passed to
-- the fitness action.
local benchWalkableSprites = {
    ["recreational_sports_01_45"] = true,
    ["recreational_sports_01_40"] = true,
    ["recreational_sports_01_43"] = true,
    ["recreational_sports_01_46"] = true,
}

local function getFrontSquare(square, facing)
    if not square or not facing then return nil end
    if facing == "S" then return square:getS() end
    if facing == "E" then return square:getE() end
    if facing == "W" then return square:getW() end
    if facing == "N" then return square:getN() end
    return nil
end

local function getBenchData(obj, allowWalkable)
    if not obj or not obj.getSprite then return nil end
    local sprite = obj:getSprite()
    if not sprite then return nil end

    local spriteName = sprite:getName()
    if not allowWalkable and spriteName and benchWalkableSprites[spriteName] then
        return nil
    end

    local props = sprite:getProperties()
    if not props or not props:has("CustomName") then return nil end
    if props:get("CustomName") ~= "Contraption" then return nil end
    if not props:has("GroupName") or props:get("GroupName") ~= "Fitness" then return nil end

    return {
        object = obj,
        spriteName = spriteName,
        facing = props:has("Facing") and props:get("Facing") or nil,
        isWalkable = spriteName and benchWalkableSprites[spriteName] or false,
    }
end

local function setPlayerFacingFromMachine(player, facing)
    FWOFacingByPlayer[player] = nil
    if facing == "N" then FWOFacingByPlayer[player] = IsoDirections.S
    elseif facing == "E" then FWOFacingByPlayer[player] = IsoDirections.W
    elseif facing == "S" then FWOFacingByPlayer[player] = IsoDirections.N
    elseif facing == "W" then FWOFacingByPlayer[player] = IsoDirections.E
    end
end

-- Iterate all object collections used by B42 for a square. Returning true from
-- the visitor stops the scan immediately.
local function visitSquareObjects(square, visitor)
    if not square then return false end
    local objectLists = {
        square:getObjects(),
        square:getStaticMovingObjects(),
        square:getMovingObjects(),
        square:getSpecialObjects(),
    }

    for _, objectList in ipairs(objectLists) do
        if objectList then
            for i = 0, objectList:size() - 1 do
                if visitor(objectList:get(i)) then return true end
            end
        end
    end
    return false
end

-- A click on the walkable/front half must resolve only to the controller whose
-- own Facing property says that this exact square is its front square. This is
-- deliberately stricter than "first bench on an adjacent tile" so nearby gym
-- equipment cannot hijack the click.
local function findBenchPairedWithWalkable(walkableData)
    if not walkableData or not walkableData.isWalkable then return nil end

    local walkableSquare = walkableData.object:getSquare()
    if not walkableSquare then return nil end

    local matches = {}
    local seen = {}
    local directions = { IsoDirections.N, IsoDirections.S, IsoDirections.W, IsoDirections.E }

    for _, direction in ipairs(directions) do
        local adjacentSquare = walkableSquare:getAdjacentSquare(direction)
        visitSquareObjects(adjacentSquare, function(candidate)
            local candidateData = getBenchData(candidate, false)
            if not candidateData or not candidateData.facing then return false end

            if getFrontSquare(candidate:getSquare(), candidateData.facing) ~= walkableSquare then
                return false
            end

            -- The two furniture halves normally carry the same Facing value.
            -- When it is available on the clicked half, use it to disambiguate
            -- dense layouts even further.
            if walkableData.facing and candidateData.facing ~= walkableData.facing then
                return false
            end

            if not seen[candidate] then
                seen[candidate] = true
                table.insert(matches, candidateData)
            end
            return false
        end)
    end

    -- Never guess when a pathological layout produces more than one geometrical
    -- match. A missing option is preferable to operating the wrong machine.
    if #matches == 1 then return matches[1] end
    return nil
end

FWOUseBenchPressMenu.doBuildMenu = function(player, context, worldobjects)
    local selectedBench = nil
    FWOFacingByPlayer[player] = nil

    -- Highest priority: the object PZ says was directly clicked. The previous
    -- B42 implementation accidentally returned from doBuildMenu here, which
    -- made clicking the actual controller suppress the context-menu option.
    for _, object in ipairs(worldobjects) do
        local data = getBenchData(object, false)
        if data then
            selectedBench = data
            break
        end
    end

    -- Some context-menu calls expose only another object from the clicked
    -- square. Search that square itself, but do not expand the target radius.
    local clickedSquares = {}
    local seenSquares = {}
    if not selectedBench then
        for _, object in ipairs(worldobjects) do
            local square = object and object.getSquare and object:getSquare() or nil
            if square then
                local key = square:getX() .. "," .. square:getY() .. "," .. square:getZ()
                if not seenSquares[key] then
                    seenSquares[key] = true
                    table.insert(clickedSquares, square)
                end
            end
        end

        for _, square in ipairs(clickedSquares) do
            visitSquareObjects(square, function(candidate)
                local data = getBenchData(candidate, false)
                if data then
                    selectedBench = data
                    return true
                end
                return false
            end)
            if selectedBench then break end
        end
    end

    -- If the player clicked the bench's walkable/front half, resolve its exact
    -- paired controller by geometry. Do not search from arbitrary floor tiles.
    if not selectedBench then
        for _, square in ipairs(clickedSquares) do
            local walkablePieces = {}
            visitSquareObjects(square, function(candidate)
                local data = getBenchData(candidate, true)
                if data and data.isWalkable then
                    table.insert(walkablePieces, data)
                end
                return false
            end)

            for _, walkableData in ipairs(walkablePieces) do
                selectedBench = findBenchPairedWithWalkable(walkableData)
                if selectedBench then break end
            end
            if selectedBench then break end
        end
    end

    if not selectedBench then return end

    local benchObject = selectedBench.object
    setPlayerFacingFromMachine(player, selectedBench.facing)

    local actionType = "benchpress"

    -- Show live regularity next to the option label. getRegularity() can return -1
    -- before the exercise has ever been recorded for this character, so floor that
    -- at 0 for display; the number itself is intentional, not debug leftover.
    local regularity = math.max(0, math.floor(getSpecificPlayer(player):getFitness():getRegularity("benchpress")))
    local optionLabel = getText("IGUI_BenchPress_Tooltip") .. " (" .. regularity .. ")"

    context:addOption(optionLabel,
                      worldobjects,
                      FWOUseBenchPressMenu.onUseBench,
                      getSpecificPlayer(player),
                      benchObject,
                      actionType,
                      5760)
end

FWOUseBenchPressMenu.getFrontSquare = function(square, facing)
    return getFrontSquare(square, facing)
end

FWOUseBenchPressMenu.getFacing = function(properties)
    local facing = nil

    if properties:has("Facing") then
        facing = properties:get("Facing")
    end
    return facing
end

FWOUseBenchPressMenu.walkToFront = function(thisPlayer, benchObject)
    local spriteName = benchObject:getSprite():getName()
    if not spriteName then return false end

    local properties = benchObject:getSprite():getProperties()
    local facing = FWOUseBenchPressMenu.getFacing(properties)
    if not facing then return false end

    local frontSquare = FWOUseBenchPressMenu.getFrontSquare(benchObject:getSquare(), facing)
    if not frontSquare then
        thisPlayer:Say(getText("IGUI_bench_rotate_bug"))
        return false
    end

    -- If player is already on the front square, just set direction
    local playerSquare = thisPlayer:getCurrentSquare()
    if playerSquare and playerSquare == frontSquare then
        local objectFacing = FWOFacingByPlayer[thisPlayer:getPlayerNum()]
        if objectFacing then thisPlayer:setDir(objectFacing) end
        return true
    end

    -- Walk to the front square
    if AdjacentFreeTileFinder.privTrySquare(benchObject:getSquare(), frontSquare) then
        ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, frontSquare))
        return true
    end
    return false
end

local barbellTypes = { "BarBell", "BarBell_Forged" }
local dumbbellTypes = { "DumbBell", "DumbBell_Forged" }

local function collectInventoryItemsByType(inventory, itemTypes)
    local result = {}
    for _, itemType in ipairs(itemTypes) do
        local items = inventory:getAllTypeRecurse(itemType)
        if items then
            for i = 0, items:size() - 1 do
                table.insert(result, items:get(i))
            end
        end
    end
    return result
end

-- Bench press accepts either one barbell or two dumbbells. A barbell is kept
-- as the preferred option to preserve the mod's existing behaviour. Dumbbells
-- may be any mix of the vanilla and forged variants.
local function getBenchPressEquipment(player)
    local inventory = player:getInventory()

    local barbells = collectInventoryItemsByType(inventory, barbellTypes)
    if #barbells > 0 then
        return { mode = "barbell", primary = barbells[1] }
    end

    local dumbbells = collectInventoryItemsByType(inventory, dumbbellTypes)
    if #dumbbells >= 2 then
        return {
            mode = "dumbbells",
            primary = dumbbells[1],
            secondary = dumbbells[2],
        }
    end

    return nil
end

local function equipBenchPressEquipment(player, equipment)
    if equipment.mode == "barbell" then
        ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), equipment.primary, true, true)
        return
    end

    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), equipment.primary, true, false)
    ISWorldObjectContextMenu.equip(player, player:getSecondaryHandItem(), equipment.secondary, false, false)
end

-- equip() only queues the equip action(s); it doesn't wait for them. Queuing the
-- fitness action right behind an equip that silently fails to resolve (item lost,
-- hands not free, etc.) left the character mid-turn forever: waitToStart() polls
-- shouldBeTurning() while the exercise sound already loops from serverStart(), so
-- the player saw a frozen, silent-animation "fake start" with no XP. This timed
-- action sits behind the queued equip action(s) and only fires onVerified() once
-- the expected items actually ended up in hand, or bails out with a message.
FWOVerifyEquipAction = ISBaseTimedAction:derive("FWOVerifyEquipAction")

function FWOVerifyEquipAction:isValid()
    return true
end

-- Compare by item TYPE, not object identity. equip() can hand back a different
-- Lua wrapper for what is conceptually the same equipped item (e.g. after being
-- routed through an unequip/re-equip pair for the previous hand item), so a
-- reference/identity check against the item captured before equipping never
-- matched even once both dumbbells were visibly in hand - the player stood
-- there fully equipped while this action waited forever for a match that could
-- never happen.
local function isEquippedType(item, expectedTypes)
    if not item then return false end
    local itemType = item:getType()
    for _, expectedType in ipairs(expectedTypes) do
        if itemType == expectedType then return true end
    end
    return false
end

function FWOVerifyEquipAction:equipmentMatches()
    local expectedTypes = self.equipment.mode == "barbell" and barbellTypes or dumbbellTypes
    local primaryOk = isEquippedType(self.character:getPrimaryHandItem(), expectedTypes)
    local secondaryOk = self.equipment.mode ~= "dumbbells" or isEquippedType(self.character:getSecondaryHandItem(), expectedTypes)
    return primaryOk and secondaryOk
end

-- ISBaseTimedAction has no isFinished() hook - completion is purely time-driven
-- (maxTime) unless something calls forceComplete() itself. The previous version
-- defined isFinished() expecting it to be polled like a coroutine condition, but
-- the engine never calls it, so the action just sat there forever (with maxTime
-- 0 potentially auto-completing before it could ever check anything, depending
-- on timing). update() IS a real per-tick hook; drive the check from there and
-- finish the action manually with forceComplete().
function FWOVerifyEquipAction:isUsingTimeout()
    return false
end

function FWOVerifyEquipAction:update()
    if self:equipmentMatches() then
        self:forceComplete()
        return
    end
    self.ticks = self.ticks + 1
    if self.ticks >= self.maxTicks then
        self.timedOut = true
        self:forceComplete()
    end
end

function FWOVerifyEquipAction:start()
    self.ticks = 0
    -- No visible UI for this action: it's a background wait, not something the
    -- player should see a progress/loading bar for.
    self.useProgressBar = false
end

function FWOVerifyEquipAction:perform()
    if self.timedOut then
        self.character:Say(getText("IGUI_need_barbell"))
    else
        self.onVerified()
    end
    ISBaseTimedAction.perform(self)
end

function FWOVerifyEquipAction:new(character, equipment, onVerified)
    local o = ISBaseTimedAction.new(self, character)
    o.equipment = equipment
    o.onVerified = onVerified
    o.ticks = 0
    o.maxTicks = 100 -- ~a few seconds of in-game ticks, generous enough for equip to resolve over the network
    o.maxTime = 0
    o.useProgressBar = false
    o.stopOnWalk = false
    o.stopOnRun = false
    return o
end

FWOUseBenchPressMenu.onUseBench = function(worldobjects, player, machine, actionType, length)
    local equipment = getBenchPressEquipment(player)
    if not equipment then
        player:Say(getText("IGUI_need_barbell"))
        return
    end
    -- Starting the exercise while already sitting on the ground lets the fitness
    -- action begin without the character ever standing up (walkToFront() skips
    -- its walk-to-front queue when the player is already on the front tile).
    -- The in-loop sitting check in FWOTreadmillBenchpressExercise.lua can't
    -- reliably stop that on a dedicated server, so refuse the exploit at the
    -- source instead.
    if player:isSitOnGround() then
        player:Say(getText("IGUI_sitting"))
        return
    end
    if player:getMoodles():getMoodleLevel(MoodleType.ENDURANCE) > 2 then
        player:Say(getText("IGUI_low_endurance"))
        return
    end
    if player:getMoodles():getMoodleLevel(MoodleType.PAIN) > 3 then
        player:Say(getText("IGUI_pain"))
        return
    end
    if player:getMoodles():getMoodleLevel(MoodleType.HEAVY_LOAD) > 2 then
        player:Say(getText("IGUI_heavy"))
        return
    end
    if FWOUseBenchPressMenu.walkToFront(player, machine) then
        forceDropHeavyItems(player)

        if not SandboxVars.FWOWorkingTreadmill.BenchTreadKeepBagsOn then
            for i=0,player:getWornItems():size()-1 do
                local item = player:getWornItems():get(i):getItem()
                if item and instanceof(item, "InventoryContainer") then
                    ISTimedActionQueue.add(ISUnequipAction:new(player, item, 50))
                    if SandboxVars.FWOWorkingTreadmill.BenchpressDropBags then
                        -- ISDropItemAction doesn't exist as a class; vanilla drops items to the
                        -- floor via an inventory transfer to the floor container instead (see
                        -- ISInventoryPaneContextMenu.dropItem).
                        ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, item:getContainer(), ISInventoryPage.GetFloorContainer(player:getPlayerNum())))
                    end
                end
            end
        end

        equipBenchPressEquipment(player, equipment)

        ISTimedActionQueue.add(FWOVerifyEquipAction:new(player, equipment, function()
            local fitnessAction = ISFitnessAction:new(player, actionType, length, ISFitnessUI:new(0,0, 600, 350, player), FitnessExercises.exercisesType.benchpress.type)
            local facing = FWOFacingByPlayer[player:getPlayerNum()]
            if facing then
                fitnessAction.FWOObjectFacing = facing
            end
            fitnessAction.FWOObject = machine
            ISTimedActionQueue.add(fitnessAction)
        end))
    end
end

Events.OnPreFillWorldObjectContextMenu.Add(FWOUseBenchPressMenu.doBuildMenu)
