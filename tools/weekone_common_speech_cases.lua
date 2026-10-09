__step = "fixture"
__player.getCurrentSquare = function() return {} end
__player.getX = function() return 80 end
__player.getY = function() return 80 end
__player.getZ = function() return 0 end
getSpecificPlayer = function(index) if index == 0 then return __player end end
getTimestampMs = function() return 1791414000000 end
SAO.Participants = { player = getSpecificPlayer }
SAO.Body.active, SAO.Body.foreign = {}, {}
SAO.Body.get = function(id) return SAO.Body.active[id] end
SAO.Identity.displayName = function(rec) return rec.forename .. " " .. rec.surname end
SAO.Perception.EARSHOT = 10
SAOJavaBridge.speechWeatherHearing = function() return 1 end
__ordinaryCalls = 0
SAOJavaBridge.canConverseNow = function(self, speaker, listener)
    __ordinaryCalls = __ordinaryCalls + 1
    return listener == __normalBody
end
__hearCalls, __flipHearing = 0, false
local sourceHearing = SAOJavaBridge.weekOneCanHearPlayer
SAOJavaBridge.weekOneCanHearPlayer = function(self, ...)
    __hearCalls = __hearCalls + 1
    if __flipHearing and __hearCalls % 2 == 0 then return false end
    return sourceHearing(self, ...)
end

function __commonCases()
    local W, C, M = SAO.WeekOneContinuity, SAO.Communication,
        SAO.MousecatInteraction
    local function eventFor(correlation)
        local output = M.nearby(__player, "session-a")
        local key = '"correlationId":"native-speech-' .. correlation .. '"'
        local at, from = nil, 1
        while true do
            local found = output:find(key, from, true)
            if not found then break end
            at, from = found, found + 1
        end
        if not at then return "" end
        local first = output:sub(1, at):match(".*(){")
        local last = output:find("}", at, true)
        return first and last and output:sub(first, last) or ""
    end
    local brain, body = __actor(701)
    body.isDead = function(self) return not self.alive end
    body.getCurrentSquare = function() return {} end
    body.x, body.y = 88, 80
    BanditZombie.CacheLightB[brain.id] = { brain = brain }
    local id = W.observeBrain(brain, body)
    local rec = __records[id]
    assert(id == "bwo-1" and C.bodyFor(id) == body,
        "exact source body absent from common physical resolver")
    assert(C.canConverse("player:active", id) and __ordinaryCalls == 0,
        "source proxy used zombie-generic hearing instead of Week One native hearing")
    local near = M.nearby(__player, "session-a")
    assert(near:find('"id":"bwo-1"', 1, true)
        and near:find('"Controller","value":"BanditsWeekOne"', 1, true),
        "source person or truthful body owner absent from nearby")

    __step = "heard-and-accepted"
    local before = #__spoken
    local answer = M.speak(__player, id, "Follow me", "typed", "one", "session-a")
    assert(answer:find('"status":"applied"', 1, true)
        and answer:find("accepted", 1, true)
        and #__spoken == before + 1 and brain.program.name == "Walker"
        and rec.weekOne.lastSpeech.source == "Mousecat-native-speech"
        and rec.weekOne.lastSpeech.inputMode == "typed"
        and rec.weekOne.lastSpeech.correlationId == "native-speech-one",
        "common speech did not reach one heard person with truthful origin")
    local receipt = M.nearby(__player, "session-a")
    assert(receipt:find('"actorId":"player:active"', 1, true)
        and receipt:find('"stage":"utterance-accepted"', 1, true),
        "common receipt attributed player's accepted utterance to another body")

    __step = "protected-queue"
    local queue, task = __move(brain, id)
    task.lock = true
    before = #__spoken
    local refused = M.speak(__player, id, "Stay here", "dictated", "two", "session-a")
    assert(refused:find("refused", 1, true) and #__spoken == before + 1
        and brain.tasks == queue and brain.tasks[1] == task
        and rec.weekOne.lastSpeech.inputMode == "dictated"
        and rec.weekOne.lastSpeech.correlationId == "native-speech-two",
        "source protected task was cleared or refusal lost provenance")

    __step = "hearing-and-stale"
    __heard = false; before = #__spoken
    assert(M.speak(__player, id, "Hello", "typed", "three", "session-a")
        :find('"status":"rejected"', 1, true) and #__spoken == before,
        "unheard source person received or emitted common speech")
    __heard = true; __flipHearing = true; __hearCalls = 0
    local unheard = M.speak(__player, id, "Hello", "typed", "four", "session-a")
    assert(unheard:find("did not hear", 1, true) and #__spoken == before + 1
        and M.nearby(__player, "session-a")
            :find('"stage":"utterance-unheard"', 1, true),
        "speech heard at access then lost before emission was falsely received")
    __flipHearing = false
    local born = body.md.SAOWeekOneBorn
    body.md.SAOWeekOneBorn = -1
    assert(C.bodyFor(id) == nil and not C.canConverse("player:active", id)
        and not M.nearby(__player, "session-a")
            :find('"id":"bwo-1"', 1, true),
        "stale body marker remained in common speech or nearby")
    body.md.SAOWeekOneBorn = born
    local chat = W.onSourceChat
    W.onSourceChat = nil; before = #__spoken
    assert(M.speak(__player, id, "Hello", "typed", "missing", "session-a")
        :find('"status":"rejected"', 1, true) and #__spoken == before,
        "missing source controller fell through to fabricated ordinary reception")
    W.onSourceChat = chat

    __step = "dormant-and-normal"
    local secondBrain, secondBody = __actor(702)
    secondBody.isDead = body.isDead
    secondBody.getCurrentSquare = body.getCurrentSquare
    secondBody.x, secondBody.y = 80, 81
    BanditZombie.CacheLightB[secondBrain.id] = { brain = secondBrain }
    local secondId = W.observeBrain(secondBrain, secondBody)
    rec.dormantSleeping = false
    rec.speechAccessOrigin = "generated-empty-traits"
    __records[secondId].dormantSleeping = false
    __records[secondId].speechAccessOrigin = "generated-empty-traits"
    assert(not C.canConverse(id, secondId, "dormant-encounter"),
        "claimed loaded source proxies used generic dormant speech")
    __normalBody = { isDead = function() return false end,
        getCurrentSquare = function() return {} end,
        getX = function() return 80 end, getY = function() return 79 end,
        getZ = function() return 0 end }
    __records.normal = { id = "normal", forename = "Normal", surname = "Person" }
    SAO.Body.active.normal = __normalBody
    before = #__spoken
    local ordinary = M.speak(__player, "normal", "Hello", "typed", "five", "session-a")
    assert(ordinary:find('"status":"applied"', 1, true)
        and #__spoken == before + 1 and __ordinaryCalls > 0,
        "ordinary SAO native speech was diverted through Week One")
    assert(eventFor("five"):find('"actorId":"player:active"', 1, true)
        and eventFor("five"):find('"recipientId":"normal"', 1, true),
        "ordinary uninterpreted speech attributed to recipient")

    __step = "ordinary-receipt-attribution"
    __records.normal.bodyOwner = "ExternalOwner"
    C.registerExecutionOwner("ExternalOwner", {
        bodyFor = function() return __normalBody end,
        receiveUtterance = function() return { received = true } end,
    })
    local received = M.speak(__player, "normal", "Hello", "typed", "six", "session-a")
    assert(received:find('"status":"applied"', 1, true)
        and eventFor("six"):find('"actorId":"player:active"', 1, true)
        and eventFor("six"):find('"recipientId":"normal"', 1, true)
        and eventFor("six"):find('"stage":"utterance-response"', 1, true),
        "ordinary owner receipt attributed player speech to recipient: "
            .. received .. "/" .. eventFor("six"))
    C.unregisterExecutionOwner("ExternalOwner")
    __records.normal.bodyOwner = nil
    local noCompanion = M.speak(__player, "normal", "Follow me", "typed", "seven", "session-a")
    assert(noCompanion:find('"status":"applied"', 1, true)
        and eventFor("seven"):find('"actorId":"player:active"', 1, true)
        and eventFor("seven"):find('"recipientId":"normal"', 1, true)
        and eventFor("seven"):find('"stage":"utterance-refused"', 1, true),
        "ordinary inactive-companion refusal attributed player speech to recipient")
    SAO.Controller = SAO.Controller or {}
    SAO.Controller.agents = { normal = { rec = __records.normal, companioning = true } }
    SAO.Command = { order = function() return "refuses", "No" end }
    SAO.Voice = { answer = function() end }
    local refusedOrder = M.speak(__player, "normal", "Follow me", "typed", "eight", "session-a")
    assert(refusedOrder:find('"status":"applied"', 1, true)
        and eventFor("eight"):find('"actorId":"player:active"', 1, true)
        and eventFor("eight"):find('"recipientId":"normal"', 1, true)
        and eventFor("eight"):find('"stage":"utterance-refused"', 1, true),
        "ordinary judged refusal attributed player speech to recipient")
    SAO.Command.order = function() return "complies" end
    local acceptedOrder = M.speak(__player, "normal", "Follow me", "typed", "nine", "session-a")
    assert(acceptedOrder:find('"status":"applied"', 1, true)
        and eventFor("nine"):find('"actorId":"player:active"', 1, true)
        and eventFor("nine"):find('"recipientId":"normal"', 1, true)
        and eventFor("nine"):find('"stage":"utterance-accepted"', 1, true),
        "ordinary accepted order attributed player speech to recipient")

    __step = "nearest-cap"
    for n = 703, 723 do
        local actor, shell = __actor(n)
        shell.isDead, shell.getCurrentSquare = body.isDead, body.getCurrentSquare
        shell.x, shell.y = 80 + (723 - n) * 0.15, 80
        BanditZombie.CacheLightB[actor.id] = { brain = actor }
        assert(W.observeBrain(actor, shell), "stress source person not admitted")
    end
    local capped = M.nearby(__player, "session-a")
    assert(not capped:find('"id":"bwo-1"', 1, true)
        and capped:find('"id":"bwo-20"', 1, true)
        and capped:find('"omittedPeople":', 1, true),
        "final global cap kept far source over a nearer person")
    return "PASS"
end

function __safeCommon()
    local ok, result = pcall(__commonCases)
    if ok then return result end
    return "FAIL:" .. tostring(__step) .. ":" .. tostring(result)
end
