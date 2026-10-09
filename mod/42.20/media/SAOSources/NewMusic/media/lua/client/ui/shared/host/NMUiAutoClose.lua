require "ui/shared/host/NMDeviceUiTime"

local uiAutoClose = {}

local function autoCloseThresholdSq()
    return NMDeviceUIRange.getWorldInteractionRangeSq and NMDeviceUIRange.getWorldInteractionRangeSq() or (2.8 * 2.8)
end

local function buildResult(shouldClose, reason, detail)
    return {
        shouldClose = shouldClose == true,
        reason = tostring(reason or ""),
        detail = detail or {},
    }
end

local function resolvePlayer(window)
    local playerNum = window and tonumber(window.playerNum) or 0
    local player = getPlayer and getPlayer(playerNum) or nil
    if not (player and player.DistToSquared) then
        return nil
    end
    return player
end

local function buildLocationDetail(location, thresholdSq, distSq)
    local detail = {
        mode = tostring(location and location.mode or ""),
        thresholdSq = tonumber(thresholdSq) or 0,
        distSq = tonumber(distSq) or 0,
        x = tonumber(location and location.x) or 0,
        y = tonumber(location and location.y) or 0,
    }
    local square = location and location.square or nil
    if square and square.getX and square.getY and square.getZ then
        detail.squareX = square:getX()
        detail.squareY = square:getY()
        detail.squareZ = square:getZ()
    end
    return detail
end

local function playerHasVehicleWindowAccess(player, target)
    if not (player and target) then
        return false, "missing_player_or_target"
    end

    local activeVehicle = player.getVehicle and player:getVehicle() or nil
    if not activeVehicle then
        return false, "player_not_in_vehicle"
    end

    local targetVehicleId = tostring(target.vehicleId or "")
    local activeVehicleId = activeVehicle.getId and tostring(activeVehicle:getId() or "") or ""
    if targetVehicleId ~= "" and activeVehicleId ~= targetVehicleId then
        return false, "vehicle_changed"
    end

    local seat = activeVehicle.getSeat and tonumber(activeVehicle:getSeat(player)) or -1
    if seat == nil or seat < 0 or seat > 1 then
        return false, "seat_invalid"
    end

    local targetPartId = tostring(target.partId or "Radio")
    for partIndex = 1, activeVehicle:getPartCount() do
        local part = activeVehicle:getPartByIndex(partIndex - 1)
        if part and tostring(part.getId and part:getId() or "") == targetPartId then
            local profile = NMDeviceProfiles and NMDeviceProfiles.getVehicleProfile and NMDeviceProfiles.getVehicleProfile(part) or nil
            if profile then
                return true, "ok"
            end
            break
        end
    end

    return false, "part_profile_missing"
end

local function evaluateVehicleTarget(player, target)
    local vehicle = target and target.vehicleRef or nil
    if not (vehicle and vehicle.getX and vehicle.getY) then
        return buildResult(false, "non_portable_resolved")
    end

    local hasAccess, accessReason = playerHasVehicleWindowAccess(player, target)
    if not hasAccess then
        return buildResult(true, "vehicle_access_lost", {
            accessReason = tostring(accessReason or "unknown"),
            vehicleId = tostring(target and target.vehicleId or ""),
            partId = tostring(target and target.partId or ""),
        })
    end

    local thresholdSq = autoCloseThresholdSq()
    local distSq = tonumber(player:DistToSquared(tonumber(vehicle:getX()) or 0, tonumber(vehicle:getY()) or 0)) or 0
    return buildResult(distSq > thresholdSq, "fast_vehicle", {
        thresholdSq = thresholdSq,
        distSq = distSq,
        vehicleId = tostring(target and target.vehicleId or ""),
        partId = tostring(target and target.partId or ""),
    })
end

local function evaluatePortableTarget(player, window, target, resolved)
    local portableTarget = target or (window and window.target) or nil
    if not portableTarget then
        return buildResult(false, "missing_target")
    end

    local item = portableTarget.itemRef
    local location = NMDeviceUIRange.resolvePortableTargetLocation and NMDeviceUIRange.resolvePortableTargetLocation(portableTarget, item) or nil
    local thresholdSq = autoCloseThresholdSq()
    if location and location.mode == "detached_placed" then
        local distSqDetached = tonumber(player:DistToSquared(location.x, location.y)) or 0
        return buildResult(distSqDetached > thresholdSq, "fast_detached", buildLocationDetail(location, thresholdSq, distSqDetached))
    end
    if location and location.mode == "placed_world" then
        local distSqFast = tonumber(player:DistToSquared(location.x, location.y)) or 0
        return buildResult(distSqFast > thresholdSq, "fast_world", buildLocationDetail(location, thresholdSq, distSqFast))
    end
    if location and location.mode == "inventory" then
        return buildResult(false, "inventory")
    end
    if location and location.mode == "unresolved" then
        return buildResult(false, "item_ref_unresolved")
    end

    local resolvedContext = resolved
    if resolvedContext == nil and window and window.resolveContext then
        resolvedContext = window:resolveContext()
    end
    if not resolvedContext then
        return buildResult(true, "resolved_nil")
    end

    local resolvedLocation = NMDeviceUIRange.resolvePortableTargetLocation and NMDeviceUIRange.resolvePortableTargetLocation(portableTarget, resolvedContext.item) or nil
    if resolvedLocation and resolvedLocation.mode == "inventory" then
        return buildResult(false, "resolved_inventory")
    end
    if not resolvedLocation or not resolvedLocation.requiresDistanceCheck then
        return buildResult(false, "no_position", {
            kind = tostring(resolvedContext.kind or ""),
            mode = tostring(resolvedLocation and resolvedLocation.mode or ""),
        })
    end

    local distSq = tonumber(player:DistToSquared(resolvedLocation.x, resolvedLocation.y)) or 0
    return buildResult(distSq > thresholdSq, "resolved_distance", buildLocationDetail(resolvedLocation, thresholdSq, distSq))
end

function uiAutoClose.evaluateWindowTarget(window, target, resolved)
    local player = resolvePlayer(window)
    if not player then
        return buildResult(false, "no_player_or_dist")
    end

    local activeTarget = target or (window and window.target) or nil
    if not activeTarget then
        return buildResult(false, "missing_target")
    end
    if activeTarget.kind == "vehicle" then
        return evaluateVehicleTarget(player, activeTarget)
    end
    return evaluatePortableTarget(player, window, activeTarget, resolved)
end

function uiAutoClose.getNowMs()
    return NMDeviceUiTime.nowMs()
end

function uiAutoClose.buildProbeEvent(family, target, result, options)
    local opts = options or {}
    local detail = result and result.detail or nil
    local familyName = tostring(family or "ui")
    local event = nil

    if result.reason == "no_player_or_dist" then
        event = {
            tag = "autoclose_skip",
            detail = string.format("ui=%s reason=no_player_or_dist", familyName),
            throttleMs = 1000,
        }
    elseif result.reason == "inventory" then
        event = {
            tag = "autoclose_skip",
            detail = string.format("ui=%s reason=item_in_inventory", familyName),
            throttleMs = 1000,
        }
    elseif result.reason == "item_ref_unresolved" then
        event = {
            tag = "autoclose_item_ref",
            detail = string.format("ui=%s reason=item_ref_unresolved", familyName),
            throttleMs = 1000,
        }
    elseif result.reason == "resolved_nil" then
        event = {
            tag = "autoclose_resolve",
            detail = string.format("ui=%s result=true reason=resolved_nil", familyName),
            throttleMs = 750,
        }
    elseif result.reason == "resolved_inventory" then
        event = {
            tag = "autoclose_resolve",
            detail = string.format("ui=%s result=false reason=resolved_inventory_item", familyName),
            throttleMs = 1000,
        }
    elseif result.reason == "non_portable_resolved" then
        event = {
            tag = "autoclose_resolve",
            detail = string.format("ui=%s result=false reason=non_portable_resolved", familyName),
            throttleMs = 1000,
        }
    elseif result.reason == "no_position" then
        local noPositionDetail = string.format("ui=%s result=false reason=no_position", familyName)
        if opts.includeNoPositionKind == true then
            noPositionDetail = string.format(
                "%s kind=%s",
                noPositionDetail,
                tostring(detail and detail.kind or "")
            )
        end
        event = {
            tag = "autoclose_resolve",
            detail = noPositionDetail,
            throttleMs = 1000,
        }
    elseif result.reason == "fast_vehicle" then
        event = {
            tag = "autoclose_fast_vehicle",
            detail = string.format(
                "ui=%s result=%s distSq=%.3f thresholdSq=%.3f vehicleId=%s partId=%s",
                familyName,
                tostring(result.shouldClose == true),
                tonumber(detail and detail.distSq) or 0,
                tonumber(detail and detail.thresholdSq) or 0,
                tostring(detail and detail.vehicleId or ""),
                tostring(detail and detail.partId or "")
            ),
            throttleMs = 750,
            counter = "autoclose.fast",
        }
    elseif result.reason == "vehicle_access_lost" then
        event = {
            tag = "autoclose_vehicle_access",
            detail = string.format(
                "ui=%s result=%s reason=%s vehicleId=%s partId=%s",
                familyName,
                tostring(result.shouldClose == true),
                tostring(detail and detail.accessReason or "unknown"),
                tostring(detail and detail.vehicleId or ""),
                tostring(detail and detail.partId or "")
            ),
            throttleMs = 250,
            counter = "autoclose.fast",
        }
    elseif result.reason == "fast_detached" then
        event = {
            tag = "autoclose_detached",
            detail = string.format(
                "ui=%s result=%s distSq=%.3f thresholdSq=%.3f x=%.2f y=%.2f",
                familyName,
                tostring(result.shouldClose == true),
                tonumber(detail and detail.distSq) or 0,
                tonumber(detail and detail.thresholdSq) or 0,
                tonumber(detail and detail.x) or 0,
                tonumber(detail and detail.y) or 0
            ),
            throttleMs = 750,
            counter = opts.detachedCounter,
        }
    elseif result.reason == "fast_world" then
        event = {
            tag = "autoclose_fast_item",
            detail = string.format(
                "ui=%s result=%s distSq=%.3f thresholdSq=%.3f square=%d,%d,%d itemId=%s",
                familyName,
                tostring(result.shouldClose == true),
                tonumber(detail and detail.distSq) or 0,
                tonumber(detail and detail.thresholdSq) or 0,
                tonumber(detail and detail.squareX) or 0,
                tonumber(detail and detail.squareY) or 0,
                tonumber(detail and detail.squareZ) or 0,
                tostring(target and target.itemId or "")
            ),
            throttleMs = 750,
            counter = opts.fastWorldCounter,
        }
    else
        local resolvedDetail = string.format(
            "ui=%s result=%s",
            familyName,
            tostring(result.shouldClose == true)
        )
        if opts.includeResolvedKind == true then
            resolvedDetail = string.format("%s kind=%s", resolvedDetail, tostring(detail and detail.kind or "item"))
        end
        resolvedDetail = string.format(
            "%s mode=%s distSq=%.3f thresholdSq=%.3f x=%.2f y=%.2f",
            resolvedDetail,
            tostring(detail and detail.mode or ""),
            tonumber(detail and detail.distSq) or 0,
            tonumber(detail and detail.thresholdSq) or 0,
            tonumber(detail and detail.x) or 0,
            tonumber(detail and detail.y) or 0
        )
        event = {
            tag = "autoclose_resolve",
            detail = resolvedDetail,
            throttleMs = 750,
        }
    end

    return event
end

function uiAutoClose.tickWindowAutoClose(window, options)
    if not window then
        return false
    end

    local opts = options or {}
    local nowMs = tonumber(opts.nowMs) or uiAutoClose.getNowMs()
    local pollMs = math.max(1, tonumber(opts.pollMs) or 250)
    local lastCheckMs = tonumber(window._nmLastDistanceCheckMs) or 0
    local deltaMs = nowMs - lastCheckMs
    local due = deltaMs >= pollMs
    local probeFn = type(opts.probeFn) == "function" and opts.probeFn or nil

    if due then
        window._nmLastDistanceCheckMs = nowMs
    end

    if probeFn then
        probeFn(window, {
            due = due,
            nowMs = nowMs,
            lastCheckMs = lastCheckMs,
            deltaMs = deltaMs,
            reasonTag = tostring(opts.reasonTag or ""),
        })
    end

    if not due then
        return false
    end

    local result = nil
    local evaluateFn = type(opts.evaluateFn) == "function" and opts.evaluateFn or nil
    if evaluateFn then
        result = evaluateFn(window, opts)
    else
        result = uiAutoClose.evaluateWindowTarget(window, opts.target, opts.resolved)
    end

    if type(opts.resultFn) == "function" then
        opts.resultFn(window, result, {
            nowMs = nowMs,
            pollMs = pollMs,
            reasonTag = tostring(opts.reasonTag or ""),
        })
    end

    if not (result and result.shouldClose == true) then
        return false
    end

    local closeFn = type(opts.closeFn) == "function" and opts.closeFn or nil
    if closeFn then
        closeFn(window, opts, result)
    elseif window.close then
        window:close()
    end
    return true
end

return uiAutoClose
