__step = "setup"
__player = {}
__otherPlayer = {}
__body = {}
__brain = { id = 73, born = 12.5 }
__record = { id = "bwo-73", weekOne = {
    source = "BanditsWeekOne", status = "external" } }
__active = { callout = false, horn = false }
__calloutOccurrence = nil
__canHear = true
__stateReads = 0
__hearingReads = 0
__speechCalls = 0
__programCalls = 0
__sourceAvailable = true
__owner = "BanditsWeekOne"
getSpecificPlayer = function(slot) if slot == 0 then return __player end end
getGameTime = function() return {getWorldAgeHours = function() return 12.5 end} end
SAO = {
    Identity = { get = function(id) if id == "bwo-73" then return __record end end },
    Claims = { heldBy = function(rec) if rec == __record then return __owner end end },
    Standing = { playerKey = function(player) return player == __player and "player-1" or nil end },
    WeekOneContinuity = {
        loadedPersonIdsNear = function(player, reach, limit)
            assert(player == __player and limit == 128 and (reach == 90 or reach == 150))
            return {"bwo-73"}, 0
        end,
        sourceBodyFor = function(id)
            assert(id == "bwo-73")
            if __sourceAvailable then return __body, __brain end
        end,
        onSourceChat = function() __speechCalls = __speechCalls + 1 end,
    },
}
SAOJavaBridge = {
    weekOneNativeSignalActive = function(self, player, kind)
        assert(player == __player and (kind == "callout" or kind == "horn"))
        __stateReads = __stateReads + 1
        return __active[kind]
    end,
    weekOneNativeCalloutOccurrence = function(self, player)
        assert(player == __player)
        return __calloutOccurrence
    end,
    weekOneNativeSignalHeard = function(self, player, body, id, brainId, born, kind)
        assert(player == __player and body == __body and id == "bwo-73"
            and brainId == 73 and born == 12.5
            and (kind == "callout" or kind == "horn"))
        __hearingReads = __hearingReads + 1
        return __canHear
    end,
}
Bandit = { SetProgram = function() __programCalls = __programCalls + 1 end }
__player.Say = function() __speechCalls = __speechCalls + 1 end
Events = {
    OnPlayerUpdate = { handlers = {}, Add = function(fn)
        Events.OnPlayerUpdate.handlers[#Events.OnPlayerUpdate.handlers + 1] = fn end },
    OnGameStart = { handlers = {}, Add = function(fn)
        Events.OnGameStart.handlers[#Events.OnGameStart.handlers + 1] = fn end },
    OnGameExit = { handlers = {}, Add = function(fn)
        Events.OnGameExit.handlers[#Events.OnGameExit.handlers + 1] = fn end },
}

function __cases()
    local N = SAO.WeekOneNativeSignal
    __step = "registration-and-quiet-baseline"
    assert(#Events.OnPlayerUpdate.handlers == 1
        and #Events.OnGameStart.handlers == 1
        and #Events.OnGameExit.handlers == 1)
    assert(N.observePlayer(__player) == 0 and __hearingReads == 0
        and __record.weekOne.lastNativeSignal == nil,
        "quiet source token became contact without native occurrence")

    __step = "sticky-state-without-callout-occurrence"
    __active.callout = true
    assert(N.observePlayer(__player) == 0 and __hearingReads == 0,
        "sticky native state without Callout occurrence became contact")

    __step = "native-callout-heard"
    __calloutOccurrence = "callout-pulse-1"
    assert(N.observePlayer(__player) == 1 and __hearingReads == 1
        and __record.weekOne.lastNativeSignal.kind == "callout"
        and __record.weekOne.lastNativeSignal.playerKey == "player-1"
        and __record.weekOne.lastNativeSignal.source == "native-callout"
        and __record.weekOne.lastNativeSignal.heardAtHours == 12.5,
        "actual callout and heard body did not record sound contact")
    assert(__speechCalls == 0 and __programCalls == 0,
        "sound contact became speech, task or hostility")

    __step = "held-event-dedup"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 1,
        "one held native callout produced a duplicate")

    __step = "second-genuine-callout-while-flag-sticky"
    __calloutOccurrence = "callout-pulse-2"
    assert(N.observePlayer(__player) == 1 and __hearingReads == 2,
        "second actual native Callout was lost behind sticky flag")

    __step = "stale-occurrence-reappearance"
    __calloutOccurrence = nil
    assert(N.observePlayer(__player) == 0 and __hearingReads == 2,
        "absent native occurrence became sound contact")
    __calloutOccurrence = "callout-pulse-2"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 2,
        "stale Callout occurrence was replayed after a missing read")

    __step = "new-unheard-callout"
    __canHear = false
    __calloutOccurrence = "callout-pulse-3"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 3
        and __record.weekOne.lastNativeSignal.kind == "callout",
        "unheard native callout became contact")

    __step = "stale-body"
    __sourceAvailable = false
    __canHear = true
    __calloutOccurrence = "callout-pulse-4"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 3,
        "stale source body borrowed sound contact")
    __sourceAvailable = true

    __step = "owner-changed"
    __owner = "other"
    __calloutOccurrence = "callout-pulse-5"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 3,
        "foreign owner borrowed sound contact")
    __owner = "BanditsWeekOne"

    __step = "rebound-native-horn"
    __active.callout = false
    __calloutOccurrence = nil
    N.observePlayer(__player)
    __active.horn = true
    assert(N.observePlayer(__player) == 1 and __hearingReads == 4
        and __record.weekOne.lastNativeSignal.kind == "horn"
        and __record.weekOne.lastNativeSignal.source == "native-horn"
        and __speechCalls == 0 and __programCalls == 0,
        "rebound native horn did not remain a sound-only contact")
    assert(N.observePlayer(__player) == 0 and __hearingReads == 4,
        "held horn produced a duplicate")

    __step = "other-player"
    __active.horn = false
    assert(N.observePlayer(__otherPlayer) == 0 and __hearingReads == 4,
        "foreign player borrowed local native signal")

    __step = "world-reset-baseline"
    N.reset()
    __active.callout = true
    __calloutOccurrence = "callout-pulse-6"
    assert(N.observePlayer(__player) == 0 and __hearingReads == 4,
        "world reset replayed old native state")
    return "PASS"
end

function __safe()
    local ok, result = pcall(__cases)
    if ok then return result end
    return "FAIL:" .. tostring(__step) .. ":" .. tostring(result)
end
