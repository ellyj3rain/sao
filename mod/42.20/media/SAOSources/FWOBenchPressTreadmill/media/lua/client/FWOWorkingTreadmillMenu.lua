--[[
    FWO Working Treadmill - Context Menu
    Build 42

    Adds treadmill exercise option to context menu
]]

local FWOWorkingTreadmillMenu = {}

-- Per-player facing state (indexed by player number, NOT global) — prevents
-- local co-op / split-screen players from clobbering each other's facing
-- while building context menus on the same client.
local FWOFacingByPlayer = {}

-- These are the walkable/front halves of the multi-tile treadmill. They should
-- be selectable by the player, but they are not the controller object passed
-- to the fitness action.
local treadmillWalkableSprites = {
    ["recreational_sports_01_28"] = true,
    ["recreational_sports_01_31"] = true,
    ["recreational_sports_01_37"] = true,
    ["recreational_sports_01_38"] = true,
}

local function getFrontSquare(square, facing)
    if not square or not facing then return nil end
    if facing == "S" then return square:getS() end
    if facing == "E" then return square:getE() end
    if facing == "W" then return square:getW() end
    if facing == "N" then return square:getN() end
    return nil
end

-- A treadmill spans two squares. Generator power can be reported on either
-- half, so treat the controller or its exact front/walkable square as powered.
-- Grid-power behavior remains unchanged.
local function hasTreadmillPower(treadmillObject)
    if SandboxVars.ElecShutModifier > -1 and GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier then
        return true
    end

    if not treadmillObject or not treadmillObject.getSquare then return false end
    local controllerSquare = treadmillObject:getSquare()
    if controllerSquare and controllerSquare:haveElectricity() then return true end

    local sprite = treadmillObject:getSprite()
    local properties = sprite and sprite:getProperties() or nil
    local facing = properties and properties:has("Facing") and properties:get("Facing") or nil
    local frontSquare = getFrontSquare(controllerSquare, facing)
    return frontSquare ~= nil and frontSquare:haveElectricity()
end

local function getTreadmillData(obj, allowWalkable)
    if not obj or not obj.getSprite then return nil end
    local sprite = obj:getSprite()
    if not sprite then return nil end

    local spriteName = sprite:getName()
    if not allowWalkable and spriteName and treadmillWalkableSprites[spriteName] then
        return nil
    end

    local props = sprite:getProperties()
    if not props or not props:has("CustomName") then return nil end
    if props:get("CustomName") ~= "Hamster Wheel" then return nil end
    if not props:has("GroupName") or props:get("GroupName") ~= "Human" then return nil end

    return {
        object = obj,
        spriteName = spriteName,
        facing = props:has("Facing") and props:get("Facing") or nil,
        isWalkable = spriteName and treadmillWalkableSprites[spriteName] or false,
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

-- Resolve a click on the treadmill's walkable/front half only to the controller
-- whose Facing property makes this exact square its front square. This avoids
-- selecting an arbitrary nearby treadmill in dense gym layouts.
local function findTreadmillPairedWithWalkable(walkableData)
    if not walkableData or not walkableData.isWalkable then return nil end

    local walkableSquare = walkableData.object:getSquare()
    if not walkableSquare then return nil end

    local matches = {}
    local seen = {}
    local directions = { IsoDirections.N, IsoDirections.S, IsoDirections.W, IsoDirections.E }

    for _, direction in ipairs(directions) do
        local adjacentSquare = walkableSquare:getAdjacentSquare(direction)
        visitSquareObjects(adjacentSquare, function(candidate)
            local candidateData = getTreadmillData(candidate, false)
            if not candidateData or not candidateData.facing then return false end

            if getFrontSquare(candidate:getSquare(), candidateData.facing) ~= walkableSquare then
                return false
            end

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

    if #matches == 1 then return matches[1] end
    return nil
end

FWOWorkingTreadmillMenu.doBuildMenu = function(player, context, worldobjects)
    local selectedTreadmill = nil
    FWOFacingByPlayer[player] = nil

    -- Highest priority: directly clicked controller object. The previous B42
    -- code returned from doBuildMenu on success, suppressing the menu option.
    for _, object in ipairs(worldobjects) do
        local data = getTreadmillData(object, false)
        if data then
            selectedTreadmill = data
            break
        end
    end

    local clickedSquares = {}
    local seenSquares = {}
    if not selectedTreadmill then
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

        -- Search only the clicked square itself in case the context payload did
        -- not include the controller object directly.
        for _, square in ipairs(clickedSquares) do
            visitSquareObjects(square, function(candidate)
                local data = getTreadmillData(candidate, false)
                if data then
                    selectedTreadmill = data
                    return true
                end
                return false
            end)
            if selectedTreadmill then break end
        end
    end

    -- Only a recognised secondary treadmill tile is allowed to expand the
    -- lookup to adjacent squares, and only via exact front-square geometry.
    if not selectedTreadmill then
        for _, square in ipairs(clickedSquares) do
            local walkablePieces = {}
            visitSquareObjects(square, function(candidate)
                local data = getTreadmillData(candidate, true)
                if data and data.isWalkable then
                    table.insert(walkablePieces, data)
                end
                return false
            end)

            for _, walkableData in ipairs(walkablePieces) do
                selectedTreadmill = findTreadmillPairedWithWalkable(walkableData)
                if selectedTreadmill then break end
            end
            if selectedTreadmill then break end
        end
    end

    if not selectedTreadmill then return end

    local treadmillObject = selectedTreadmill.object
    setPlayerFacingFromMachine(player, selectedTreadmill.facing)

    local actionType = "treadmill"

    -- Show live regularity next to the option label. getRegularity() can return -1
    -- before the exercise has ever been recorded for this character, so floor that
    -- at 0 for display; the number itself is intentional, not debug leftover.
    local regularity = math.max(0, math.floor(getSpecificPlayer(player):getFitness():getRegularity("treadmill")))
    local optionLabel = getText("IGUI_Treadmill_Tooltip") .. " (" .. regularity .. ")"

    context:addOption(optionLabel,
                      worldobjects,
                      FWOWorkingTreadmillMenu.onUseTreadmill,
                      getSpecificPlayer(player),
                      treadmillObject,
                      actionType,
                      5760)
end

FWOWorkingTreadmillMenu.walkToFront = function(thisPlayer, treadmillObject)
    local frontSquare = nil
    local spriteName = treadmillObject:getSprite():getName()
    if not spriteName then return false end

    local properties = treadmillObject:getSprite():getProperties()
    local facing = properties:has("Facing") and properties:get("Facing") or nil
    if not facing then return false end

    frontSquare = getFrontSquare(treadmillObject:getSquare(), facing)
    if not frontSquare then return false end

    -- If player is already on the front square, just set direction
    local playerSquare = thisPlayer:getCurrentSquare()
    if playerSquare and playerSquare == frontSquare then
        local objectFacing = FWOFacingByPlayer[thisPlayer:getPlayerNum()]
        if objectFacing then thisPlayer:setDir(objectFacing) end
        return true
    end

    -- Walk to the front square
    if AdjacentFreeTileFinder.privTrySquare(treadmillObject:getSquare(), frontSquare) then
        ISTimedActionQueue.add(ISWalkToTimedAction:new(thisPlayer, frontSquare))
        return true
    end
    return false
end

FWOWorkingTreadmillMenu.onUseTreadmill = function(worldobjects, player, machine, actionType, length)
    if not hasTreadmillPower(machine) then
        player:Say(getText("IGUI_treadmill_needs_electricity"))
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
    if FWOWorkingTreadmillMenu.walkToFront(player, machine) then
        forceDropHeavyItems(player)
        player:setPrimaryHandItem(nil)
        player:setSecondaryHandItem(nil)

        if not SandboxVars.FWOWorkingTreadmill.BenchTreadKeepBagsOn then
            for i=0,player:getWornItems():size()-1 do
                local item = player:getWornItems():get(i):getItem()
                if item and instanceof(item, "InventoryContainer") then
                    ISTimedActionQueue.add(ISUnequipAction:new(player, item, 50))
                    if SandboxVars.FWOWorkingTreadmill.TreadmillDropBags then
                        -- ISDropItemAction doesn't exist as a class; vanilla drops items to the
                        -- floor via an inventory transfer to the floor container instead (see
                        -- ISInventoryPaneContextMenu.dropItem).
                        ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, item:getContainer(), ISInventoryPage.GetFloorContainer(player:getPlayerNum())))
                    end
                end
            end
        end

        local fitnessAction = ISFitnessAction:new(player, actionType, length, ISFitnessUI:new(0,0, 600, 350, player), FitnessExercises.exercisesType.treadmill.type)
        local facing = FWOFacingByPlayer[player:getPlayerNum()]
        if facing then
            fitnessAction.FWOObjectFacing = facing
        end
        fitnessAction.FWOObject = machine
        ISTimedActionQueue.add(fitnessAction)
    end
end

Events.OnPreFillWorldObjectContextMenu.Add(FWOWorkingTreadmillMenu.doBuildMenu)