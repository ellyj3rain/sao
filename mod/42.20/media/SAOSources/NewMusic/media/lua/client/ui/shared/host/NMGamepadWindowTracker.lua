NMGamepadWindowTracker = NMGamepadWindowTracker or {}

NMGamepadWindowTracker._entriesByPlayer = NMGamepadWindowTracker._entriesByPlayer or {}

local function normalizePlayerNum(playerNum)
    return tonumber(playerNum) or 0
end

local function isWindowVisible(window)
    if not (window and window.javaObject) then
        return false
    end
    if window.getIsVisible then
        return window:getIsVisible() == true
    end
    if window.isVisible then
        return window:isVisible() == true
    end
    return true
end

local function windowMatchesPlayer(window, playerNum)
    return normalizePlayerNum(window and window.playerNum) == normalizePlayerNum(playerNum)
end

local function windowHasTarget(window)
    return type(window and window.target) == "table" and tostring(window.target.kind or "") ~= ""
end

local function isWindowTrackable(window, playerNum)
    if not window then
        return false
    end
    if playerNum ~= nil and not windowMatchesPlayer(window, playerNum) then
        return false
    end
    return isWindowVisible(window) and windowHasTarget(window)
end

local function ensurePlayerEntries(playerNum)
    local normalized = normalizePlayerNum(playerNum)
    local entries = NMGamepadWindowTracker._entriesByPlayer[normalized]
    if type(entries) ~= "table" then
        entries = {}
        NMGamepadWindowTracker._entriesByPlayer[normalized] = entries
    end
    return entries
end

local function compactEntries(entries, playerNum)
    local kept = {}
    for i = 1, #entries do
        local entry = entries[i]
        local window = entry and entry.window or nil
        if isWindowTrackable(window, playerNum) then
            kept[#kept + 1] = entry
        end
    end
    return kept
end

local function removeWindowEntry(entries, window)
    local kept = {}
    for i = 1, #entries do
        local entry = entries[i]
        if not (entry and entry.window == window) then
            kept[#kept + 1] = entry
        end
    end
    return kept
end

function NMGamepadWindowTracker.markWindow(window, family)
    local playerNum = normalizePlayerNum(window and window.playerNum)
    if not isWindowTrackable(window, playerNum) then
        return false
    end
    local entries = ensurePlayerEntries(playerNum)
    entries = compactEntries(entries, playerNum)
    entries = removeWindowEntry(entries, window)
    entries[#entries + 1] = {
        family = tostring(family or "unknown"),
        window = window
    }
    NMGamepadWindowTracker._entriesByPlayer[playerNum] = entries
    return true
end

function NMGamepadWindowTracker.unregisterWindow(window)
    local playerNum = normalizePlayerNum(window and window.playerNum)
    local entries = ensurePlayerEntries(playerNum)
    entries = removeWindowEntry(entries, window)
    entries = compactEntries(entries, playerNum)
    NMGamepadWindowTracker._entriesByPlayer[playerNum] = entries
end

function NMGamepadWindowTracker.getActiveEntry(playerNum)
    local normalized = normalizePlayerNum(playerNum)
    local entries = ensurePlayerEntries(normalized)
    entries = compactEntries(entries, normalized)
    NMGamepadWindowTracker._entriesByPlayer[normalized] = entries
    return entries[#entries] or nil
end

function NMGamepadWindowTracker.hasActiveWindow(playerNum)
    return NMGamepadWindowTracker.getActiveEntry(playerNum) ~= nil
end

