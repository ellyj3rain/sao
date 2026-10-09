__step = "setup"
__tick, __hours = 200, 12.5
__player, __vehicle, __body = {}, {}, {}
__brain = { id = 73, born = 12.5 }
__record = { id = "bwo-73", weekOne = {
    source = "BanditsWeekOne", status = "external" } }
__owner, __canHear = "BanditsWeekOne", true
__active = { callout = false, horn = false }
__calloutOccurrence = nil
__hearingReads = 0
__player.getX = function() return 10.25 end
__player.getY = function() return 11.75 end
__player.getZ = function() return 0 end
__player.getVehicle = function() return __vehicle end
__vehicle.getX = function() return 20.5 end
__vehicle.getY = function() return 21.5 end
__vehicle.getZ = function() return 0 end
__body.getX = function() return 11.25 end
__body.getY = function() return 11.75 end
getGameTime = function() return { getWorldAgeHours = function() return __hours end } end
getSpecificPlayer = function(slot) return slot == 0 and __player or nil end
SAO = {
    History = { ticks = function() return __tick end },
    Identity = { get = function(id) return id == "bwo-73" and __record or nil end },
    Claims = { heldBy = function(rec) return rec == __record and __owner or nil end },
    Standing = { playerKey = function(player) return player == __player and "player-1" or nil end },
    WeekOneContinuity = {
        loadedPersonIdsNear = function() return { "bwo-73" } end,
        sourceBodyFor = function(id)
            if id == "bwo-73" then return __body, __brain end
        end,
    },
}
SAOJavaBridge = {
    weekOneNativeSignalActive = function(self, player, kind)
        return player == __player and __active[kind]
    end,
    weekOneNativeCalloutOccurrence = function(self, player)
        return player == __player and __calloutOccurrence or nil
    end,
    weekOneNativeSignalHeard = function(self, player, body, id, brainId, born, kind)
        assert(player == __player and body == __body and id == "bwo-73"
            and brainId == 73 and born == 12.5)
        __hearingReads = __hearingReads + 1
        return __canHear and __active[kind]
    end,
}
Events = { OnPlayerUpdate = { Add = function() end },
    OnGameStart = { Add = function() end }, OnGameExit = { Add = function() end } }

function __privateCases()
    local P, N = SAO.Perception, SAO.WeekOneNativeSignal
    __step = "quiet-native-state"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 0
        and #P.weekOneNativeSignals("bwo-73", __body, __tick) == 0,
        "quiet native state entered private perception")

    __step = "sticky-state-without-occurrence"
    __active.callout = true
    assert(N.observePlayer(__player) == 0 and __hearingReads == 0,
        "sticky native state without Callout occurrence entered private Perception")

    __step = "native-callout-private-origin"
    __calloutOccurrence = "native-pulse-1"
    assert(N.observePlayer(__player) == 1 and __hearingReads == 1,
        "native callout did not reach canonical Perception")
    local cues = P.weekOneNativeSignals("bwo-73", __body, __tick)
    assert(#cues == 1 and cues[1].kind == "callout"
        and cues[1].source == "native-sound" and cues[1].x == 10.25
        and cues[1].y == 11.75 and cues[1].z == 0
        and cues[1].distance == 1 and cues[1].heardAt == 200
        and cues[1].heardAtHours == 12.5 and cues[1].playerKey == nil
        and cues[1].speaker == nil and cues[1].words == nil
        and cues[1].hostile == nil and cues[1].task == nil,
        "callout cue lost real body origin or invented social meaning")
    assert(P.beliefs["bwo-73"] == nil,
        "private sound cue became an inferred person or threat belief")
    cues[1].kind = "forged"
    assert(P.weekOneNativeSignals("bwo-73", __body, __tick)[1].kind == "callout",
        "query returned mutable private cue authority")

    __step = "held-key-is-one-occurrence"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 1
        and #P.weekOneNativeSignals("bwo-73", __body, __tick) == 1,
        "one held native callout duplicated a private cue")

    __step = "second-genuine-callout"
    __calloutOccurrence = "native-pulse-2"
    assert(N.observePlayer(__player) == 1 and __hearingReads == 2
        and #P.weekOneNativeSignals("bwo-73", __body, __tick) == 2,
        "second actual Callout did not reach private Perception")

    __step = "stale-occurrence-reappearance"
    __calloutOccurrence = nil
    N.observePlayer(__player)
    __calloutOccurrence = "native-pulse-2"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 2
        and #P.weekOneNativeSignals("bwo-73", __body, __tick) == 2,
        "stale Callout occurrence replayed into private Perception")

    __step = "unheard-native-action"
    __canHear = false
    __calloutOccurrence = "native-pulse-3"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 3
        and #P.weekOneNativeSignals("bwo-73", __body, __tick) == 2,
        "unheard native action entered private Perception")

    __step = "native-horn-vehicle-origin"
    __active.callout = false
    N.observePlayer(__player)
    __canHear = true
    __active.horn = true
    __tick, __hours = 201, 12.6
    assert(N.observePlayer(__player) == 1 and __hearingReads == 4,
        "native horn did not reach canonical Perception")
    cues = P.weekOneNativeSignals("bwo-73", __body, __tick)
    assert(#cues == 3 and cues[3].kind == "horn"
        and cues[3].x == 20.5 and cues[3].y == 21.5
        and cues[3].z == 0 and cues[3].heardAtHours == 12.6,
        "horn cue did not use actual driven vehicle location")
    assert(#P.weekOneNativeSignals("bwo-73", {}, __tick) == 0,
        "another body read this person's private sound")

    __step = "source-ownership-and-body"
    __active.horn = false
    N.observePlayer(__player)
    __owner = "other"
    __active.callout = true
    __calloutOccurrence = "native-pulse-4"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 4,
        "foreign owner borrowed native sound")
    __owner = "BanditsWeekOne"
    __active.callout = false
    N.observePlayer(__player)
    local oldBody = __body
    __body = {}
    assert(P.acquireWeekOneNativeSignal("bwo-73", oldBody,
        __player, __brain, "callout") == nil,
        "retired body borrowed current private hearing")
    __body = oldBody

    __step = "bounded-runtime-memory"
    for i = 1, 12 do
        __tick = 201 + i
        __hours = 12.6 + i / 100
        __active.callout = true
        __calloutOccurrence = "native-pulse-" .. tostring(i + 4)
        assert(N.observePlayer(__player) == 1,
            "fresh native callout occurrence was lost")
    end
    cues = P.weekOneNativeSignals("bwo-73", __body, __tick)
    assert(#cues == 8 and cues[1].heardAt == 206 and cues[8].heardAt == 213,
        "private signal intake exceeded its bound or retained wrong episodes")
    assert(#P.weekOneNativeSignals("bwo-73", __body, __tick + 121) == 0,
        "stale native cue remained actionable")
    P.forgetSoundCues("bwo-73", __body)
    assert(#P.weekOneNativeSignals("bwo-73", __body, __tick) == 0,
        "body release retained private native cue")
    return "PASS"
end

function __safePrivate()
    local ok, result = pcall(__privateCases)
    if ok then return result end
    return "FAIL:" .. tostring(__step) .. ":" .. tostring(result)
end
