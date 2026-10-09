-- Native shout and driven horn occurrences reach an exact retained Week One
-- person as sound contact. BWOChat's quiet Q tokens are not spoken words.
SAO = SAO or {}
local N = SAO.WeekOneNativeSignal or {}
SAO.WeekOneNativeSignal = N

local previous

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function nativeState(player, kind)
    if not (SAOJavaBridge and SAOJavaBridge.weekOneNativeSignalActive) then
        return false end
    local ok, active = pcall(function()
        return SAOJavaBridge:weekOneNativeSignalActive(player, kind)
    end)
    return ok and active == true
end

local function nativeCalloutOccurrence(player)
    if not (SAOJavaBridge and SAOJavaBridge.weekOneNativeCalloutOccurrence) then
        return nil end
    local ok, occurrence = pcall(function()
        return SAOJavaBridge:weekOneNativeCalloutOccurrence(player)
    end)
    return ok and type(occurrence) == "string" and occurrence ~= ""
        and occurrence or nil
end

local function oneContact(player, kind)
    local W = SAO.WeekOneContinuity
    if not (W and type(W.loadedPersonIdsNear) == "function"
        and type(W.sourceBodyFor) == "function"
        and SAO.Identity and SAO.Identity.get
        and SAO.Claims and SAO.Claims.heldBy
        and SAO.Standing and SAO.Standing.playerKey
        and SAOJavaBridge and SAOJavaBridge.weekOneNativeSignalHeard) then return 0 end
    local okKey, playerKey = pcall(SAO.Standing.playerKey, player)
    if not okKey or type(playerKey) ~= "string" or playerKey == "" then return 0 end
    local okTime, atHours = pcall(function() return getGameTime():getWorldAgeHours() end)
    if not okTime or not finite(atHours) or atHours < 0 then return 0 end
    local okList, ids = pcall(W.loadedPersonIdsNear, player,
        kind == "horn" and 150 or 90, 128)
    if not okList or type(ids) ~= "table" then return 0 end
    local heardCount = 0
    for _, id in ipairs(ids) do
        local okSource, body, brain = pcall(W.sourceBodyFor, id)
        local rec = okSource and SAO.Identity.get(id)
        local phase = rec and rec.weekOne
        if body and type(brain) == "table" and phase and not rec.dead
            and phase.status == "external" and not phase.pending
            and phase.source == "BanditsWeekOne"
            and SAO.Claims.heldBy(rec) == "BanditsWeekOne" then
            local perception = SAO.Perception
            local ok, heard
            if perception and type(perception.acquireWeekOneNativeSignal) == "function" then
                local cue
                ok, cue = pcall(perception.acquireWeekOneNativeSignal,
                    id, body, player, brain, kind)
                heard = type(cue) == "table" and cue.kind == kind
                    and cue.source == "native-sound"
            else
                -- Keep the source-only native signal probe usable when it
                -- loads this module without the full shared Perception pillar.
                ok, heard = pcall(function()
                    return SAOJavaBridge:weekOneNativeSignalHeard(player, body,
                        id, brain.id, brain.born, kind)
                end)
            end
            if ok and heard == true then
                phase.lastNativeSignal = {
                    source = "native-" .. kind,
                    kind = kind, playerKey = playerKey,
                    brainId = brain.id, born = brain.born,
                    heardAtHours = atHours,
                }
                heardCount = heardCount + 1
            end
        end
    end
    return heardCount
end

function N.reset()
    previous = nil
end

-- OnPlayerUpdate runs after the native key action. The installed Callout()
-- leaves callOut true after its WorldSound expires, so only the exact new
-- Callout pulse identifies a later shout. The first observation is a baseline.
function N.observePlayer(player)
    if not player or not getSpecificPlayer or player ~= getSpecificPlayer(0) then
        return 0 end
    local callout = nativeState(player, "callout")
    local calloutOccurrence = callout and nativeCalloutOccurrence(player) or nil
    local horn = nativeState(player, "horn")
    if not previous or previous.player ~= player then
        previous = { player = player, calloutOccurrence = calloutOccurrence,
            horn = horn }
        return 0
    end
    local heard = 0
    if calloutOccurrence and calloutOccurrence ~= previous.calloutOccurrence then
        previous.calloutOccurrence = calloutOccurrence
        heard = heard + oneContact(player, "callout")
    end
    if horn and not previous.horn then
        heard = heard + oneContact(player, "horn")
    end
    previous.horn = horn
    return heard
end

if Events then
    if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(N.observePlayer) end
    if Events.OnGameStart then Events.OnGameStart.Add(N.reset) end
    if Events.OnGameExit then Events.OnGameExit.Add(N.reset) end
end
