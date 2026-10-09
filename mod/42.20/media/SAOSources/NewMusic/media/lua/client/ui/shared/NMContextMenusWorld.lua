local env = _G.NMContextMenusEnv
setfenv(1, env)

function eachWorldObject(worldObjects, fn)
    if not worldObjects or type(fn) ~= "function" then
        return
    end
    if type(worldObjects) == "table" then
        if #worldObjects > 0 then
            for i = 1, #worldObjects do
                fn(worldObjects[i])
            end
            return
        end
        for _, obj in pairs(worldObjects) do
            fn(obj)
        end
        return
    end
    if worldObjects.size and worldObjects.get then
        for i = 0, worldObjects:size() - 1 do
            fn(worldObjects:get(i))
        end
    end
end

function squareKey(square)
    if not square or not square.getX or not square.getY or not square.getZ then
        return nil
    end
    return string.format("%d:%d:%d", square:getX(), square:getY(), square:getZ())
end

function pushWorldCandidate(candidates, seen, obj, preferHead, excludeMediaContainers)
    local item = obj and obj.getItem and obj:getItem() or nil
    local profile = item and NMDeviceProfiles.getForItem(item) or nil
    if not (item and profile and NMDeviceProfiles.canPlacedWorldPlayback(profile)) then
        return
    end
    if excludeMediaContainers and profile.isMediaContainerOnly == true then
        return
    end
    local itemId = NMCore.itemId(item) or tostring(item)
    if seen[itemId] then
        return
    end
    seen[itemId] = true
    local row = { obj = obj, item = item, profile = profile }
    if preferHead then
        table.insert(candidates, 1, row)
    else
        candidates[#candidates + 1] = row
    end
end

function pushWorldMediaCaseCoverCandidate(candidates, seen, obj)
    local item = obj and obj.getItem and obj:getItem() or nil
    local profile = item and NMDeviceProfiles.getForItem(item) or nil
    if not (item and profile and profile.isMediaContainerOnly == true) then
        return
    end
    local itemId = NMCore.itemId(item) or tostring(item)
    if seen[itemId] then
        return
    end
    seen[itemId] = true
    candidates[#candidates + 1] = { obj = obj, item = item, profile = profile }
end

function scanSquareForCandidates(square, candidates, seen, excludeMediaContainers, mediaCasesOnly)
    if not square or not square.getWorldObjects then
        return
    end
    local objs = square:getWorldObjects()
    if not objs then
        return
    end
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if mediaCasesOnly == true then
            pushWorldMediaCaseCoverCandidate(candidates, seen, obj)
        else
            pushWorldCandidate(candidates, seen, obj, false, excludeMediaContainers)
        end
    end
end

function scanNeighborSquares(clickedSquares, candidates, seen, radius, excludeMediaContainers, mediaCasesOnly)
    local cell = getCell and getCell() or nil
    if not cell then
        return
    end
    local r = math.max(1, tonumber(radius) or 1)
    local scanned = {}
    for _, square in pairs(clickedSquares) do
        if square and square.getX and square.getY and square.getZ then
            local cx, cy, cz = square:getX(), square:getY(), square:getZ()
            for x = cx - r, cx + r do
                for y = cy - r, cy + r do
                    local key = string.format("%d:%d:%d", x, y, cz)
                    if not scanned[key] then
                        scanned[key] = true
                        local s = cell:getGridSquare(x, y, cz)
                        scanSquareForCandidates(s, candidates, seen, excludeMediaContainers, mediaCasesOnly == true)
                    end
                end
            end
        end
    end
end

function sortWorldCandidatesStable(left, right)
    local dl = tonumber(left and left.distance) or 999999999
    local dr = tonumber(right and right.distance) or 999999999
    if dl ~= dr then
        return dl < dr
    end
    local nl = tostring(left and left.displayName or "")
    local nr = tostring(right and right.displayName or "")
    if nl ~= nr then
        return nl < nr
    end
    return tostring(left and left.stableKey or "") < tostring(right and right.stableKey or "")
end

function NMContextMenus.resolveWorldMenuCandidates(player, worldObjects, excludeMediaContainers)
    local candidates = {}
    local seen = {}
    local clickedSquares = {}
    local primarySquare = nil

    eachWorldObject(worldObjects, function(obj)
        local square = obj and obj.getSquare and obj:getSquare() or nil
        local key = squareKey(square)
        if key and (not primarySquare) then
            primarySquare = square
            clickedSquares[key] = square
        end
    end)

    -- Explicit, simple world interaction window:
    -- scan a fixed 3x3 around the clicked square.
    if primarySquare then
        scanNeighborSquares(clickedSquares, candidates, seen, 1, excludeMediaContainers == true)
    end

    for i = 1, #candidates do
        local c = candidates[i]
        local square = c and c.obj and c.obj.getSquare and c.obj:getSquare() or nil
        c.distance = computeDistanceSq(player, square)
        c.displayName = tostring(c and c.item and c.item.getDisplayName and c.item:getDisplayName() or resolveProfileDeviceTypeLabel(c and c.profile or nil))
        c.stableKey = stableTargetKey(c and c.item, tostring(i))
        c.state = NMDeviceState.ensure(c.item, c.profile)
    end
    table.sort(candidates, sortWorldCandidatesStable)
    return candidates
end

function NMContextMenus.resolveWorldMediaCaseCoverCandidates(player, worldObjects)
    local candidates = {}
    local seen = {}
    local clickedSquares = {}
    local primarySquare = nil

    eachWorldObject(worldObjects, function(obj)
        local square = obj and obj.getSquare and obj:getSquare() or nil
        local key = squareKey(square)
        if key and (not primarySquare) then
            primarySquare = square
            clickedSquares[key] = square
        end
    end)

    if primarySquare then
        scanNeighborSquares(clickedSquares, candidates, seen, 1, false, true)
    end

    for i = 1, #candidates do
        local c = candidates[i]
        local square = c and c.obj and c.obj.getSquare and c.obj:getSquare() or nil
        c.distance = computeDistanceSq(player, square)
        c.displayName = tostring(c and c.item and c.item.getDisplayName and c.item:getDisplayName() or resolveProfileDeviceTypeLabel(c and c.profile or nil))
        c.stableKey = stableTargetKey(c and c.item, tostring(i))
        c.state = NMDeviceState.ensure(c.item, c.profile)
    end
    table.sort(candidates, sortWorldCandidatesStable)
    return candidates
end

function NMContextMenus.resolveWorldMenuCandidate(player, worldObjects, excludeMediaContainers)
    local candidates = NMContextMenus.resolveWorldMenuCandidates(player, worldObjects, excludeMediaContainers)
    if type(candidates) ~= "table" or #candidates < 1 then
        return nil, nil, nil
    end
    local best = candidates[1]
    return best.item, best.profile, best.state
end

function NMContextMenus.onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer and getSpecificPlayer(playerNum) or nil
    if not player then return end

    local selectedItems = collectSelectedInventoryItems(items)
    if #selectedItems < 1 then return end
    local seenItemIds = {}

    for i = 1, #selectedItems do
        local selected = selectedItems[i]
        local selectedId = selected and selected.getID and tostring(selected:getID() or "") or ""
        local alreadySeen = selectedId ~= "" and seenItemIds[selectedId] == true
        if not alreadySeen then
            if selectedId ~= "" then
                seenItemIds[selectedId] = true
            end
            local profile = NMDeviceProfiles.getForItem(selected)
            if profile then
                local state = NMDeviceState.ensure(selected, profile)
                if state then
                    if profile.isMediaContainerOnly == true and not isItemInPlayerInventory(player, selected) then
                        addCaseCoverOnlySubmenu(context, player, selected, profile, state)
                    else
                        addMenuByProfile(context, player, selected, profile, state)
                    end
                end
            elseif isLooseMediaItem(selected) then
                addLooseMediaSubmenu(context, player, selected)
                return
            end
        end
    end

    return
end

function addWorldCaseCoverSubmenu(context, player, candidate)
    if not (candidate and candidate.item and candidate.profile) then
        return
    end
    addCaseCoverOnlySubmenu(context, player, candidate.item, candidate.profile, candidate.state, candidate.displayName)
end

function NMContextMenus.onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if not worldObjects then return end

    local player = getSpecificPlayer and getSpecificPlayer(playerNum) or nil
    if not player then return end

    local candidates = NMContextMenus.resolveWorldMenuCandidates(player, worldObjects, true)
    local caseCoverCandidates = NMContextMenus.resolveWorldMediaCaseCoverCandidates(player, worldObjects)
    if test then
        return (type(candidates) == "table" and #candidates > 0)
            or (type(caseCoverCandidates) == "table" and #caseCoverCandidates > 0)
    end

    for i = 1, #(candidates or {}) do
        local c = candidates[i]
        local label = tostring(c.displayName or NMTranslations.ui("Device", "Device"))
        local option = context:addOption(label, player, nil)
        setOptionIcon(option, NMContextMenus.resolveMenuIconTexture(c.item, c.profile, c.state))
        local sub = ISContextMenu:getNew(context)
        context:addSubMenu(option, sub)

        addDeviceUiLifecycleOption(sub, player, c.item, c.profile, c.state)

        if canShowDeviceDisassemble(player, c.item, c.profile) then
            local disOption = sub:addOption(NMTranslations.ui("DismantleElectronicDevice", "Dismantle Electronic Device"), player, function(p, target)
                if not (target and target.item) then
                    return
                end
                queueDeviceDisassembleAction(p, target.item)
            end, c)
            setOptionIcon(disOption, resolveTextureByFullType("Base.ElectronicsScrap"))
        end

        local supportsBattery = NMDeviceProfiles.supportsBattery(c.profile)
        if supportsBattery and c.state and c.state.batteryPresent == true then
            local removeBatteryOption = sub:addOption(NMTranslations.ui("RemoveBattery", "Remove Battery"), player, function(p, target)
                if not (target and target.item) then
                    return
                end
                NMClientIntentDispatch.performIntent(p, target.item, "eject_battery", {})
            end, c)
            setOptionIcon(removeBatteryOption, resolveTextureByFullType("Base.Battery"))
        end
    end

    for i = 1, #(caseCoverCandidates or {}) do
        addWorldCaseCoverSubmenu(context, player, caseCoverCandidates[i])
    end
end


