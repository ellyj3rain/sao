(function()
    local S, P, C = SAO.Standing, SAO.Perception, SAO.Communication
    local results = {}
    local function check(name, value)
        __radioReceptionLast = name
        results[#results + 1] = name .. "=" .. tostring(value == true)
    end
    local function body(id, receiver)
        return { id = id, receiver = receiver, dead = false, asleep = false,
            deaf = false }
    end
    local function receiver(overrides)
        local value = { direct = true, itemId = 7301,
            fullType = "Base.HamRadio1", channel = 101200, on = true,
            volume = 0.8, battery = true, hasBattery = true, power = 0.8,
            useDelta = 0.0001, twoWay = true, muted = false,
            noTransmit = false }
        for key, entry in pairs(overrides or {}) do value[key] = entry end
        return value
    end
    local function reset()
        __now, __stores, __records, __bodies, __represented = 100, {}, {}, {}, {}
        __player = nil
        __clockFail = false
        P.beliefs, P.beliefVersion = {}, 0
        SAO.Organization.organizations, SAO.Organization.offices = {}, {}
        SAO.Organization.claims, SAO.Organization.decisions = {}, {}
        SAO.Organization.claimHistory, SAO.Organization.decisionHistory = {}, {}
        SAO.Organization.processes, SAO.Organization.processOrder = {}, {}
        SAO.Organization.processMeta, SAO.Organization.workReceipts =
            { sequence = 0 }, {}
        __stores.SurvivorAwareness_Beliefs = P.beliefs
        local standing = { schema = 4,
            groups = { requester = "hungry", listener = "home",
                housemate = "home", dormant = "road" },
            groupMeta = { hungry = {}, home = {}, road = {} },
            groupClaims = {}, relations = {}, claims = {}, migrations = {} }
        __stores.SurvivorAwareness_Standing = standing
        for _, id in ipairs({ "requester", "listener", "housemate",
                "dormant", "legacy", "sleeper", "depleted" }) do
            __records[id] = { id = id, x = 10, y = 10, z = 0,
                sleeping = false, dormantSleeping = false,
                hibernation = "HEAR:" .. id }
            standing.relations[id] = {}
            for _, other in ipairs({ "player", "requester", "listener",
                    "housemate", "dormant" }) do
                standing.relations[id][other] = { trust = 0.0 }
            end
        end
        __bodies.requester = body("requester", nil)
        __bodies.listener = body("listener", receiver())
        __bodies.housemate = body("housemate", receiver({ on = false,
            itemId = 7302 }))
        __records.dormant.radioState = "RAD:1:101200:0.8:0.8:0.0001"
        __records.dormant.radioStateAtHours = 100
        __records.legacy.hasRadio = true
        __records.sleeper.dormantSleeping = true
        __records.sleeper.radioState = "RAD:1:101200:0.8:0.8:0.0001"
        __records.sleeper.radioStateAtHours = 100
        __records.depleted.radioState = "RAD:1:101200:0.8:0.2:0.001"
        __records.depleted.radioStateAtHours = 90
        return standing
    end
    local function request(id)
        return P.knownAidRequest(id, "hungry")
    end

    local standing = reset()
    check("request_producer_names_speaker", S.callForBread("hungry", "requester")
        and standing.radioNews[1].speakerId == "requester")
    local news = standing.radioNews[1]
    local reached = SAOWire.deliverToListeners({ news }, "wire:1", 100)
    local heard = request("listener")
    local dormantHeard = request("dormant")
    check("wire_reaches_exact_endpoints", reached == 2
        and heard and dormantHeard and request("housemate") == nil
        and request("legacy") == nil and request("sleeper") == nil
        and request("depleted") == nil)
    local receipt = P.radioReception("listener", "wire:1")
    check("private_reception_evidence", receipt
        and receipt.sourceId == "county-wire" and receipt.frequency == 101200
        and receipt.representation == "loaded" and receipt.deviceItemId == 7301
        and #receipt.claims == 1 and receipt.claims[1].kind == "ask"
        and receipt.claims[1].speakerId == "requester")
    check("request_radio_provenance", heard and heard.source == "told"
        and heard.teller == "requester" and heard.originId == "requester"
        and heard.requestedAt == 100 and heard.acquiredAt == 100)
    check("legacy_possession_refused", __records.legacy.hasRadio == true
        and #P.radioReceptions("legacy") == 0)
    check("dormant_battery_advanced", __records.depleted.radioStateAtHours == 100
        and string.match(__records.depleted.radioState,
            "^RAD:0:101200:0%.8:0:") ~= nil)
    local version = P.beliefVersion
    check("replay_is_idempotent", SAOWire.deliverToListeners(
        { news }, "wire:1", 100) == 2 and P.beliefVersion == version
        and #P.radioReceptions("listener") == 1)

    standing = reset()
    check("source_less_request_stays_global", S.callForBread("hungry") == false
        and (not standing.radioNews or #standing.radioNews == 0)
        and request("listener") == nil
        and request("dormant") == nil)

    standing = reset()
    __records.dormant.radioState = "RAD:0:101200:0.8:0.8:0.0001"
    local playerBody = body("player", receiver({ itemId = 7399 }))
    __bodies.player = playerBody
    local beforeListener = S.trust("listener", "player")
    local beforeHousemate = S.trust("housemate", "player")
    local heardCount = S.hearPlayerOnAir("player", playerBody, 101200)
    check("player_transmission_exact_listeners", heardCount == 1
        and S.trust("listener", "player") > beforeListener
        and S.trust("housemate", "player") == beforeHousemate
        and S.heardPlayerOnAir("listener")
        and not S.heardPlayerOnAir("housemate")
        and standing.onAir.heardBy == nil)
    local playerReceipt = P.radioReceptions("listener")[1]
    check("player_receipt_precedes_effect", playerReceipt
        and playerReceipt.sourceId == "player"
        and playerReceipt.claims[1].kind == "onAir")
    playerBody.receiver.muted = true
    __now = 102
    check("muted_transmitter_refused",
        C.radioTransmitterAccess("player", 101200, playerBody) == nil
        and S.hearPlayerOnAir("player", playerBody, 101200) == false)

    standing = reset()
    check("beacon_creates_receipt", SAOWire.deliverToListeners(
        {}, "wire:beacon", 100) == 2
        and P.radioReception("listener", "wire:beacon")
        and #P.radioReception("listener", "wire:beacon").claims == 0)
    local bad = P.recordRadioReception("forged", "fake", "county-wire",
        101200, 100, { representation = "loaded", deviceItemId = 1,
            deviceType = "Base.Radio", channel = 99200, power = 1 }, {})
    check("receipt_requires_matching_channel", bad == false
        and P.radioReception("forged", "fake") == nil)
    local negativePower = P.recordRadioReception("forged", "fake-power", "county-wire",
        101200, 100, { representation = "loaded", deviceItemId = 1,
            deviceType = "Base.Radio", channel = 101200, power = -0.1 }, {})
    local excessPower = P.recordRadioReception("forged", "fake-power-high",
        "county-wire", 101200, 100, { representation = "loaded",
            deviceItemId = 1, deviceType = "Base.Radio", channel = 101200,
            power = 1.1 }, {})
    check("receipt_requires_bounded_power", negativePower == false
        and excessPower == false
        and P.radioReception("forged", "fake-power") == nil
        and P.radioReception("forged", "fake-power-high") == nil)

    standing = reset()
    check("borrowed_body_refused", C.radioReception("housemate",
        "wire:borrowed", 101200, 100, {}, __bodies.listener,
        "county-wire") == false
        and P.radioReception("housemate", "wire:borrowed") == nil)
    check("unrecorded_claim_field_refused", C.radioReception("listener",
        "wire:extra-field", 101200, 100,
        { { kind = "ask", unrecorded = "hidden" } }, nil,
        "county-wire") == false
        and P.radioReception("listener", "wire:extra-field") == nil)

    standing = reset()
    check("retroactive_reception_refused", SAOWire.deliverToListeners(
        {}, "wire:past", 99) == 0
        and P.radioReception("listener", "wire:past") == nil)
    SAO.Controller.agents.listener = { sleeping = true }
    check("loaded_controller_sleep_refused", SAOWire.deliverToListeners(
        {}, "wire:sleeping-loaded", 100) == 1
        and P.radioReception("listener", "wire:sleeping-loaded") == nil
        and P.radioReception("dormant", "wire:sleeping-loaded") ~= nil)

    standing = reset()
    __clockFail = true
    local beforeSequence = standing.onAir and standing.onAir.sequence or nil
    check("failed_clock_refuses_broadcast",
        S.beginRadioBroadcast("player", "voice") == nil
        and SAOWire.air({ setAiringBroadcast = function() end }, true) == false
        and (standing.onAir and standing.onAir.sequence or nil) == beforeSequence)

    return table.concat(results, ",")
end)()
