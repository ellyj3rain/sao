local env = _G.NMContextMenusEnv
setfenv(1, env)

function computeDistanceSq(player, square)
    if not (player and square and player.getX and player.getY and player.getZ and square.getX and square.getY and square.getZ) then
        return 999999999
    end
    local dx = (tonumber(player:getX()) or 0) - (tonumber(square:getX()) or 0)
    local dy = (tonumber(player:getY()) or 0) - (tonumber(square:getY()) or 0)
    local dz = (tonumber(player:getZ()) or 0) - (tonumber(square:getZ()) or 0)
    return (dx * dx) + (dy * dy) + ((dz * dz) * 4.0)
end

function stableTargetKey(item, fallback)
    local ft = item and item.getFullType and tostring(item:getFullType() or "") or "unknown"
    local id = item and item.getID and tostring(item:getID() or "") or ""
    if id == "" then
        id = tostring(fallback or "")
    end
    return ft .. "|" .. id
end

local function stableWindowItemKey(target)
    if not target then
        return ""
    end
    local itemId = tostring(target.itemId or "")
    if itemId ~= "" then
        return "item:" .. itemId
    end
    local uuid = tostring(target.uuid or "")
    if uuid ~= "" then
        return "uuid:" .. uuid
    end
    return ""
end

function sortTargetsStable(left, right)
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

local function resolveVehicleWindowDisplayName(window)
    local resolved = window and window.resolveContext and window:resolveContext() or nil
    local vehicle = resolved and resolved.vehicle or nil
    if not vehicle then
        return NMTranslations.ui("Vehicle", "Vehicle")
    end
    if ISVehicleMenu and ISVehicleMenu.getVehicleDisplayName then
        local ok, displayName = pcall(ISVehicleMenu.getVehicleDisplayName, vehicle)
        if ok and tostring(displayName or "") ~= "" then
            return tostring(displayName)
        end
    end
    local script = vehicle.getScript and vehicle:getScript() or nil
    local displayName = script and script.getCarModelName and tostring(script:getCarModelName() or "") or ""
    if displayName == "" then
        displayName = script and script.getName and tostring(script:getName() or "") or ""
    end
    if displayName ~= "" and getTextOrNull then
        local translated = getTextOrNull("IGUI_VehicleName" .. displayName)
        if translated and translated ~= "" then
            return translated
        end
    end
    if displayName ~= "" then
        return displayName
    end
    return NMTranslations.ui("Vehicle", "Vehicle")
end

local function resolveWindowTargetDisplayName(zone)
    local window = zone and zone.window or nil
    local target = window and window.target or nil
    if tostring(zone and zone.uiFamily or "") == "vehicle" or tostring(target and target.kind or "") == "vehicle" then
        return resolveVehicleWindowDisplayName(window)
    end
    local resolved = window and window.resolveContext and window:resolveContext() or nil
    local item = resolved and resolved.item or target and target.itemRef or nil
    local profile = resolved and resolved.profile or item and NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
    local displayName = item and resolveDeviceMenuLabel and resolveDeviceMenuLabel(item, profile) or ""
    if tostring(displayName or "") ~= "" then
        return tostring(displayName)
    end
    if window and window.title and tostring(window.title) ~= "" then
        return tostring(window.title)
    end
    return NMTranslations.ui("Device", "Device")
end

local function resolveLiveDeviceState(item, profile)
    if not (item and profile and NMDeviceState and NMDeviceState.ensure) then
        return nil
    end
    local state = NMDeviceState.ensure(item, profile)
    if NMClientDisplayStateResolver and NMClientDisplayStateResolver.resolve then
        state = NMClientDisplayStateResolver.resolve(state)
    end
    return state
end

local function canAcceptLooseMediaDevice(profile, state, carrier)
    if not profile or profile.isMediaContainerOnly == true then
        return false
    end
    if tostring(profile.supportedCarrier or "") ~= tostring(carrier or "") then
        return false
    end
    local insertedFullType = tostring(state and (state.mediaEjectFullType or state.mediaFullType) or "")
    return insertedFullType == ""
end

function collectLooseMediaInsertTargets(player, mediaItem)
    local fullType = mediaItem and mediaItem.getFullType and tostring(mediaItem:getFullType() or "") or ""
    local carrier = NMMediaContract.resolveMediaCarrier(fullType)
    local canonical = NMMediaContract.resolveMediaCanonical and NMMediaContract.resolveMediaCanonical(fullType) or fullType
    local deviceTargets = {}
    local containerTargets = {}
    local seenDevices = {}
    local seenContainers = {}
    local seenDeviceItems = {}
    local playerNum = player and player.getPlayerNum and tonumber(player:getPlayerNum()) or 0

    local inv = player and player.getInventory and player:getInventory() or nil
    if inv then
        local all = {}
        NMInventoryHelpers.collectItemsRecursive(inv, all)
        for i = 1, #all do
            local it = all[i]
            local profile = it and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(it) or nil
            local state = resolveLiveDeviceState(it, profile)
            if canAcceptLooseMediaDevice(profile, state, carrier) then
                local key = stableTargetKey(it, "inv")
                if not seenDevices[key] then
                    seenDevices[key] = true
                    seenDeviceItems["item:" .. tostring(it.getID and it:getID() or "")] = true
                    deviceTargets[#deviceTargets + 1] = {
                        category = "device",
                        item = it,
                        profile = profile,
                        state = state,
                        distance = 0,
                        displayName = tostring(it.getDisplayName and it:getDisplayName() or key),
                        stableKey = key
                    }
                end
            elseif profile and profile.isMediaContainerOnly == true and tostring(profile.supportedCarrier or "") == tostring(carrier or "") then
                local bound = NMMediaContract.resolveContainerMediaBinding and NMMediaContract.resolveContainerMediaBinding(it:getFullType()) or nil
                local accepted = false
                if NMMediaContract and NMMediaContract.areMediaEquivalent then
                    accepted = NMMediaContract.areMediaEquivalent(bound, canonical)
                else
                    accepted = tostring(bound or "") == tostring(canonical or "")
                end
                if accepted then
                    local key = stableTargetKey(it, "inv")
                    if not seenContainers[key] then
                        seenContainers[key] = true
                        containerTargets[#containerTargets + 1] = {
                            category = "container",
                            item = it,
                            profile = profile,
                            distance = 0,
                            displayName = tostring(it.getDisplayName and it:getDisplayName() or key),
                            stableKey = key
                        }
                    end
                end
            end
        end
    end

    local cell = getCell and getCell() or nil
    local square = player and player.getSquare and player:getSquare() or nil
    if cell and square then
        local px, py, pz = square:getX(), square:getY(), square:getZ()
        local radius = 2
        for x = px - radius, px + radius do
            for y = py - radius, py + radius do
                local s = cell:getGridSquare(x, y, pz)
                if s and s.getWorldObjects then
                    local objs = s:getWorldObjects()
                    if objs then
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            local it = obj and obj.getItem and obj:getItem() or nil
                            local profile = it and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(it) or nil
                            local state = resolveLiveDeviceState(it, profile)
                            if canAcceptLooseMediaDevice(profile, state, carrier) then
                                local key = stableTargetKey(it, tostring(x) .. ":" .. tostring(y))
                                if not seenDevices[key] then
                                    seenDevices[key] = true
                                    seenDeviceItems["item:" .. tostring(it.getID and it:getID() or "")] = true
                                    deviceTargets[#deviceTargets + 1] = {
                                        category = "device",
                                        item = it,
                                        profile = profile,
                                        state = state,
                                        distance = computeDistanceSq(player, s),
                                        displayName = tostring(it.getDisplayName and it:getDisplayName() or key),
                                        stableKey = key
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if NMPortableMediaDropArbiter and NMPortableMediaDropArbiter.collectZones then
        local zones = NMPortableMediaDropArbiter.collectZones(playerNum, { mediaItem })
        for i = 1, #zones do
            local zone = zones[i]
            local accepts = zone
                and zone.window
                and zone.visible == true
                and zone.enabled == true
                and zone.interactive == true
                and zone.canAcceptDraggedMedia
                and zone.canAcceptDraggedMedia({ mediaItem }) == true
            if accepts then
                local target = zone.window and zone.window.target or nil
                local itemWindowKey = target and target.kind == "item" and stableWindowItemKey(target) or ""
                if itemWindowKey == "" or not seenDeviceItems[itemWindowKey] then
                    local zoneKey = table.concat({
                        tostring(zone.uiFamily or ""),
                        tostring(zone.zoneKind or ""),
                        tostring(zone.itemId or ""),
                        tostring(zone.uuid or ""),
                        tostring(zone.window and zone.window.target and zone.window.target.vehicleId or "")
                    }, "|")
                    if not seenDevices[zoneKey] then
                        seenDevices[zoneKey] = true
                        local resolved = zone.window and zone.window.resolveContext and zone.window:resolveContext() or nil
                        local item = resolved and resolved.item or target and target.itemRef or nil
                        local profile = resolved and resolved.profile or item and NMDeviceProfiles and NMDeviceProfiles.getForItem and NMDeviceProfiles.getForItem(item) or nil
                        local state = resolved and resolved.state or item and profile and NMDeviceState and NMDeviceState.ensure and NMDeviceState.ensure(item, profile) or nil
                        deviceTargets[#deviceTargets + 1] = {
                            category = "window",
                            window = zone.window,
                            zone = zone,
                            item = item,
                            profile = profile,
                            state = state,
                            distance = 0,
                            displayName = resolveWindowTargetDisplayName(zone),
                            stableKey = zoneKey
                        }
                    end
                end
            end
        end
    end

    table.sort(deviceTargets, sortTargetsStable)
    table.sort(containerTargets, sortTargetsStable)
    return deviceTargets, containerTargets
end
