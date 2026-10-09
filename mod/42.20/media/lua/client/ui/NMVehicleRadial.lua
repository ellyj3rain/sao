-- Integrated source: NewMusic; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("NewMusic") then return end
-- Vehicle radial injection for New Music vehicle controls.
-- Canonical UI path is NMDeviceUI -> NMDeviceWindow.
NMVehicleRadial = NMVehicleRadial or {}
NMVehicleRadial.hookInstalled = NMVehicleRadial.hookInstalled or false
NMVehicleRadial.nextHookAttemptMs = NMVehicleRadial.nextHookAttemptMs or 0
NMVehicleRadial.wrapperFn = NMVehicleRadial.wrapperFn or nil
NMVehicleRadial.baseShowRadialMenu = NMVehicleRadial.baseShowRadialMenu or nil
NMVehicleRadial.installations = NMVehicleRadial.installations or 0

local function radialProbeEnabled()
    return NMCore and NMCore.logChannel and NMCore.isSubsystemDebugEnabled and NMCore.isSubsystemDebugEnabled("portable_ui") == true
end

local function logRadialProbe(tag, detail)
    if not radialProbeEnabled() then
        return
    end
    NMCore.logChannel("portable_ui", tostring(tag or "vehicle_radial"), tostring(detail or ""))
end

local function nowMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then return ms end
    end
    if getTimestamp then
        local ts = tonumber(getTimestamp())
        if ts then return ts * 1000 end
    end
    return 0
end

local function getMenuForPlayer(playerObj)
    if not playerObj then
        return nil
    end
    return getPlayerRadialMenu and getPlayerRadialMenu(playerObj:getPlayerNum()) or nil
end

local function resolveVehicleMusicPart(playerObj)
    if not playerObj then
        return nil, nil
    end
    local vehicle = playerObj.getVehicle and playerObj:getVehicle() or nil
    if not vehicle then
        return nil, nil
    end
    local seat = vehicle.getSeat and vehicle:getSeat(playerObj) or -1
    if seat < 0 or seat > 1 then
        return vehicle, nil
    end
    for partIndex = 1, vehicle:getPartCount() do
        local part = vehicle:getPartByIndex(partIndex - 1)
        local profile = NMDeviceProfiles.getVehicleProfile(part)
        if profile then
            return vehicle, part
        end
    end
    return vehicle, nil
end

local function clearMenuInjectionMarker(menu)
    if not menu then
        return
    end
    menu._nmVehicleRadialInjectedKey = nil
    menu._nmVehicleRadialInjectedPartId = nil
end

local function buildInjectionKey(playerObj, vehicle)
    local playerNum = playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or -1
    local vehicleId = vehicle and vehicle.getId and tostring(vehicle:getId() or "") or ""
    return tostring(playerNum) .. "|" .. tostring(vehicleId)
end

local function onVehicleRadialSignal(playerObj, part)
    if not playerObj or not part then return end
    local vehicle = part.getVehicle and part:getVehicle() or playerObj:getVehicle()
    if not vehicle then return end
    local profile = NMDeviceProfiles.getVehicleProfile(part)
    if not profile then return end
    NMDeviceUI.openForVehicle(playerObj:getPlayerNum(), vehicle, part)
end

local function injectVehicleRadialMenu(playerObj)
    if not playerObj then return end
    local menu = getMenuForPlayer(playerObj)
    if not menu then return end

    local vehicle, part = resolveVehicleMusicPart(playerObj)
    if not vehicle or not part then
        return
    end

    local injectKey = buildInjectionKey(playerObj, vehicle)
    local partId = part and part.getId and tostring(part:getId() or "") or ""
    if tostring(menu._nmVehicleRadialInjectedKey or "") == injectKey
        and tostring(menu._nmVehicleRadialInjectedPartId or "") == partId then
        logRadialProbe(
            "vehicle_radial_inject_skip_duplicate",
            string.format(
                "player=%s vehicleId=%s partId=%s",
                tostring(playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or -1),
                tostring(vehicle and vehicle.getId and vehicle:getId() or ""),
                tostring(partId)
            )
        )
        return
    end

    local icon = getTexture and getTexture("media/textures/UI/UI_NM_VehicleRadial.png") or nil
    menu:addSlice(NMTranslations.ui("NewMusic", "New Music"), icon, onVehicleRadialSignal, playerObj, part)
    menu._nmVehicleRadialInjectedKey = injectKey
    menu._nmVehicleRadialInjectedPartId = partId
    logRadialProbe(
        "vehicle_radial_injected",
        string.format(
            "player=%s vehicleId=%s partId=%s",
            tostring(playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or -1),
            tostring(vehicle and vehicle.getId and vehicle:getId() or ""),
            tostring(partId)
        )
    )
end

local function ensureWrapperFunction()
    if NMVehicleRadial.wrapperFn then
        return NMVehicleRadial.wrapperFn
    end
    NMVehicleRadial.wrapperFn = function(playerObj)
        local menu = getMenuForPlayer(playerObj)
        clearMenuInjectionMarker(menu)
        local baseFn = NMVehicleRadial.baseShowRadialMenu
        if type(baseFn) == "function" then
            baseFn(playerObj)
        end
        injectVehicleRadialMenu(playerObj)
    end
    return NMVehicleRadial.wrapperFn
end

function NMVehicleRadial.isHookCurrent()
    return ISVehicleMenu
        and type(ISVehicleMenu.showRadialMenu) == "function"
        and NMVehicleRadial.wrapperFn ~= nil
        and ISVehicleMenu.showRadialMenu == NMVehicleRadial.wrapperFn
end

function NMVehicleRadial.installHook()
    if NMVehicleRadial.hookInstalled == true then
        return true
    end

    local now = nowMs()
    local nextMs = tonumber(NMVehicleRadial.nextHookAttemptMs) or 0
    if now > 0 and now < nextMs then
        return false
    end
    NMVehicleRadial.nextHookAttemptMs = now + 2000

    if not ISVehicleMenu or type(ISVehicleMenu.showRadialMenu) ~= "function" then return end

    local wrapper = ensureWrapperFunction()
    local current = ISVehicleMenu.showRadialMenu
    if current == wrapper then
        NMVehicleRadial.hookInstalled = true
        return true
    end

    if NMVehicleRadial.baseShowRadialMenu then
        return false
    end

    NMVehicleRadial.baseShowRadialMenu = current
    ISVehicleMenu.showRadialMenu = wrapper
    ISVehicleMenu.NMShowRadialMenuOld = current

    local installed = ISVehicleMenu.showRadialMenu == wrapper
    NMVehicleRadial.hookInstalled = installed
    if installed then
        NMVehicleRadial.installations = (tonumber(NMVehicleRadial.installations) or 0) + 1
        logRadialProbe(
            "vehicle_radial_hook_installed",
            string.format(
                "installations=%s wrappedFn=%s",
                tostring(NMVehicleRadial.installations or 0),
                tostring(current)
            )
        )
    end
    return installed
end


