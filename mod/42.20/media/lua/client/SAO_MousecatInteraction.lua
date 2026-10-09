-- Human utterances share the existing physical speech and command architecture.
-- Runtime buffers hold bounded scalar receipts, never a fabricated persona or
-- private belief imported from Mousecat's presentation.
SAO = SAO or {}
SAO.MousecatInteraction = SAO.MousecatInteraction or {}
local M = SAO.MousecatInteraction
local histories, historyOrder, eventSequence, droppedEvents = {}, {}, 0, 0
local MAX_PEOPLE, MAX_EVENTS, MAX_HISTORY_PEOPLE = 16, 24, 64
local epochToken, epochPlayer, epochHours

local function quote(s)
    return '"' .. tostring(s or ""):gsub('[%z\1-\31\\"]', function(c)
        if c == '"' then return '\\"' end
        if c == '\\' then return '\\\\' end
        return string.format('\\u%04x', string.byte(c))
    end) .. '"'
end
local function json(value)
    if type(value) == "string" then return quote(value) end
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return tostring(value) end
    if type(value) == "boolean" then return tostring(value) end
    if type(value) ~= "table" then return "null" end
    local pieces = {}
    local empty = true; for _ in pairs(value) do empty = false; break end
    if #value > 0 or empty then
        for _, item in ipairs(value) do pieces[#pieces + 1] = json(item) end
        return "[" .. table.concat(pieces, ",") .. "]"
    end
    local keys = {}; for key in pairs(value) do keys[#keys + 1] = key end; table.sort(keys)
    for _, key in ipairs(keys) do pieces[#pieces + 1] = quote(key) .. ":" .. json(value[key]) end
    return "{" .. table.concat(pieces, ",") .. "}"
end
local function response(status, message) return json({ status = status, message = message }) end
local function playerKey(player)
    local current = (SAO.Participants and SAO.Participants.player or getSpecificPlayer)(0)
    if player == nil or current ~= player or player:isDead() or player:getCurrentSquare() == nil then return nil end
    return SAO.Standing and SAO.Standing.playerKey and SAO.Standing.playerKey(player) or nil
end
local function validText(value, maxBytes)
    return type(value) == "string" and #value > 0 and #value <= maxBytes
        and not value:find('[%z\1-\31\127]') and value:find('%S') ~= nil
end
local function record(id, stage, summary, fromId, correlation)
    if not histories[id] then
        if #historyOrder >= MAX_HISTORY_PEOPLE then
            local removed = table.remove(historyOrder, 1); droppedEvents = droppedEvents + #histories[removed]; histories[removed] = nil
        end
        historyOrder[#historyOrder + 1] = id; histories[id] = {}
    end
    local history = histories[id]
    if #history >= MAX_EVENTS then table.remove(history, 1); droppedEvents = droppedEvents + 1 end
    eventSequence = eventSequence + 1
    history[#history + 1] = { id = "utterance-" .. eventSequence,
        capturedAtUnixMs = getTimestampMs(), worldHours = getGameTime():getWorldAgeHours(),
        source = "Mousecat native speech / SAO.Communication", stage = stage, summary = summary,
        actorId = tostring(fromId), recipientId = id, correlationId = "native-speech-" .. tostring(correlation) }
end
local function physicalPerson(id)
    local rec = SAO.Identity and SAO.Identity.get and SAO.Identity.get(id)
    if not rec or rec.dead then return nil end
    local body = SAO.Communication and SAO.Communication.bodyFor and SAO.Communication.bodyFor(id)
    if not body or body:isDead() or body:getCurrentSquare() == nil then return nil end
    return rec, body
end
local function ensureEpoch(player, token)
    if not validText(token, 32) then error("Native speech lifetime unavailable") end
    local hours = getGameTime():getWorldAgeHours()
    if epochToken ~= token or epochPlayer ~= player or (epochHours and hours < epochHours) then
        histories, historyOrder, droppedEvents = {}, {}, 0
    end
    epochToken, epochPlayer, epochHours = token, player, hours
end

-- Real represented bodies only. No dormant population/whole-county iteration,
-- perception rerun, mind reading, or generated roster enters this projection.
function M.nearby(player, token)
    ensureEpoch(player, token)
    local fromId = playerKey(player)
    if not fromId or not SAO.Communication then return json({people={},omittedPeople=0,omittedEvents=droppedEvents}) end
    local ids, seen = {}, {}
    for _, source in ipairs({ SAO.Body and SAO.Body.active or {}, SAO.Body and SAO.Body.foreign or {} }) do
        for id in pairs(source) do if type(id) == "string" and not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    end
    local sourceOmitted = 0
    local weekOne = SAO.WeekOneContinuity
    if weekOne and type(weekOne.loadedPersonIdsNear) == "function" then
        local reach = SAO.Perception and SAO.Perception.EARSHOT or 10
        local ok, sourceIds, omitted = pcall(weekOne.loadedPersonIdsNear,
            player, reach, MAX_PEOPLE * 2)
        if ok and type(sourceIds) == "table" then
            for _, id in ipairs(sourceIds) do
                if type(id) == "string" and not seen[id] then
                    seen[id] = true; ids[#ids + 1] = id
                end
            end
            if type(omitted) == "number" and omitted > 0 then
                sourceOmitted = math.floor(omitted)
            end
        end
    end
    local candidates = {}
    local reach = SAO.Perception and SAO.Perception.EARSHOT or 10
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    for _, id in ipairs(ids) do
        local rec, body = physicalPerson(id)
        if body then
            local dx, dy = body:getX() - px, body:getY() - py
            local distance = dx * dx + dy * dy
            if body:getZ() == pz and distance <= reach * reach then
                candidates[#candidates + 1] = { id = id, rec = rec,
                    body = body, distance = distance }
            end
        end
    end
    SAO.Ordering.sort(candidates, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.id < b.id
    end)
    local people, bytes, omitted, omittedEvents = {}, 0, sourceOmitted, droppedEvents
    for _, candidate in ipairs(candidates) do
                local id, rec = candidate.id, candidate.rec
                local heard = SAO.Communication.canConverse(fromId, id) == true
                local sourceBody = rec.weekOne and rec.weekOne.status == "external"
                local owner = rec.bodyOwner and tostring(rec.bodyOwner)
                    or sourceBody and tostring(rec.weekOne.source)
                    or "SAO.Controller"
                local origin = rec.bodyOwner and "Registered execution owner; runner session must provide its own origin"
                    or sourceBody and "Week One source body for a persistent SAO person"
                    or "Persistent SAO person represented by a native body"
                local label = SAO.Identity.displayName(rec)
                -- Labels come from the real identity record, never a new avatar.
                if type(label) ~= "string" or #label > 160 then label = "Nearby person" end
                local person = { id = id, label = label,
                    summary = "A represented person near your native character. This is a separately timed physical speech sample.",
                    sections = { { id = "native-communication", label = "Communication", source = "SAO.Communication.canConverse",
                        perspective = "Current native hearing and represented execution owner", status = heard and "available" or "unavailable",
                        message = heard and "Within the existing native speech channel. Reception does not establish understanding."
                            or "Native hearing does not currently admit speech to this person.",
                        rows = { { label = "Controller", value = owner }, { label = "Origin", value = origin },
                            { label = "Hearing", value = heard and "Native channel admitted" or "Native channel unavailable" } } } },
                    events = {} }
                for _, event in ipairs(histories[id] or {}) do person.events[#person.events+1] = event end
                local size = #json(person)
                while bytes + size > 46000 and #person.events > 0 do
                    table.remove(person.events, 1); omittedEvents = omittedEvents + 1; size = #json(person)
                end
                if #people < MAX_PEOPLE and bytes + size <= 46000 then
                    people[#people + 1] = person; bytes = bytes + size
                else omitted = omitted + 1 end
    end
    return json({people=people,omittedPeople=omitted,omittedEvents=omittedEvents})
end

local intents = { ["wait"] = "hold", ["wait here"] = "hold", ["hold"] = "hold", ["hold position"] = "hold",
    ["follow me"] = "close", ["stay close"] = "close", ["come with me"] = "close", ["walk with me"] = "walk" }
function M.speak(player, id, text, inputMode, correlation, token)
    ensureEpoch(player, token)
    local fromId = playerKey(player)
    if not fromId or not validText(id, 128) or not validText(text, 1536)
        or (inputMode ~= "typed" and inputMode ~= "dictated") or not validText(correlation, 32) then
        return response("rejected", "Native speaker or utterance origin is unavailable.")
    end
    local rec, body = physicalPerson(id)
    if not rec or SAO.Communication.canConverse(fromId, id) ~= true then
        return response("rejected", "This person cannot currently receive your speech.")
    end
    local weekOne = SAO.WeekOneContinuity
    if rec.weekOne and rec.weekOne.status == "external" then
        if not (weekOne and type(weekOne.sourceBodyFor) == "function"
            and type(weekOne.onSourceChat) == "function") then
            return response("rejected", "The source person's speech controller is unavailable.")
        end
        local sourceBody, sourceBrain = weekOne.sourceBodyFor(id)
        if sourceBody ~= body or not sourceBrain or #text > 512 then
            return response("rejected", "The source person or utterance is unavailable.")
        end
        -- This source path emits the native player utterance itself. Calling
        -- player:Say here as well would create two physical speech events.
        local ok, received, reason = pcall(weekOne.onSourceChat,
            sourceBrain, body, player, text, false,
            { source = "Mousecat-native-speech", inputMode = inputMode,
                correlationId = "native-speech-" .. correlation })
        if not ok then return response("unknown", "Native speech outcome could not be confirmed.") end
        if received ~= true then
            if reason == "not-heard" then
                record(id, "utterance-unheard",
                    "Native player speech was emitted but this source person did not hear it.",
                    fromId, correlation)
                return response("applied", "Native speech was emitted; this person did not hear it.")
            end
            return response("unknown", "Native speech outcome could not be confirmed.")
        end
        local speech = rec.weekOne.lastSpeech
        if type(speech) ~= "table" or speech.playerKey ~= fromId
            or speech.utterance ~= text:sub(1, 160) then
            return response("unknown", "Native speech was received; its interpretation could not be confirmed.")
        end
        local decision = speech.decision
        local stage = decision == "accepted" and "utterance-accepted"
            or decision == "refused" and "utterance-refused"
            or "utterance-response"
        record(id, stage, "Week One source person " .. tostring(decision)
            .. " the heard utterance; subsequent action remains separately observed.",
            fromId, correlation)
        if reason == "response-unavailable" then
            return response("applied", "Received; " .. tostring(decision)
                .. ". The source person's answer was not displayed.")
        end
        return response("applied", "Received; " .. tostring(decision)
            .. ": " .. tostring(speech.response or "No spoken answer was available."))
    end
    local emitted = pcall(function() player:Say(text) end)
    if not emitted then return response("rejected", "Native speech emission failed.") end
    record(id, "utterance-heard-uninterpreted", text, fromId, correlation)
    -- An external assistant must actively register its real controller. This
    -- passes an observed utterance, not the other person's private state.
    local owner = rec.bodyOwner and SAO.Communication.executionOwners[tostring(rec.bodyOwner)]
    if owner and type(owner.receiveUtterance) == "function" then
        local ok, receipt = pcall(owner.receiveUtterance, id, rec, {
            fromId = fromId, recipientId = id, text = text, inputMode = inputMode,
            source = "native-human-speech", correlationId = "native-speech-" .. correlation,
            capturedAtUnixMs = getTimestampMs(), worldHours = getGameTime():getWorldAgeHours() })
        if ok and type(receipt) == "table" and receipt.received == true then
            record(id, "utterance-response", "Registered controller received the utterance; subsequent action remains its own evidence.", fromId, correlation)
            return response("applied", "The registered controller received your utterance.")
        end
        return response("applied", "Native speech was received; the registered controller did not establish an interpretation.")
    end
    local normalized = text:lower():gsub('[%p]+$', ''):match('^%s*(.-)%s*$')
    local kind = intents[normalized]
    if not kind then return response("applied", "Native speech was received. No supported instruction was inferred from these words.") end
    local agent = SAO.Controller and SAO.Controller.agents and SAO.Controller.agents[id]
    if not agent or not agent.companioning then
        record(id, "utterance-refused", "This person is not an active companion; no follow or hold state was assigned.", fromId, correlation)
        return response("applied", "This person is not an active companion. No movement instruction was applied.")
    end
    local ok, verdict, reason = pcall(SAO.Command.order, fromId, id, kind, nil)
    if not ok or (verdict ~= "complies" and verdict ~= "reluctant") then
        local message = ok and tostring(reason or verdict or "No answer") or "Command judgment failed"
        if #message > 280 then message = "The source response exceeded the bounded speech report." end
        record(id, "utterance-refused", message, fromId, correlation)
        if SAO.Voice and SAO.Voice.answer then pcall(SAO.Voice.answer, id, "orderNo") end
        return response("applied", "Received; refused: " .. message)
    end
    -- Exactly the existing companion menu semantics, after its Command.order
    -- judgment and recorded process reception. No arbitrary locomotion order.
    if kind == "hold" then agent.holdPosition = true
    elseif kind == "close" then agent.holdPosition = nil; agent.followTight = true
    else agent.holdPosition = nil; agent.followTight = nil end
    if rec.weekOne and rec.weekOne.status == "transferred"
        and SAO.Controller and type(SAO.Controller.noteWeekOneCompanionOrder) == "function" then
        pcall(SAO.Controller.noteWeekOneCompanionOrder, id, fromId,
            kind == "hold" and "hold" or "follow")
    end
    record(id, "utterance-accepted", "Accepted " .. kind .. " through SAO.Command; movement is still observed independently.", fromId, correlation)
    if SAO.Voice and SAO.Voice.answer then pcall(SAO.Voice.answer, id, verdict == "reluctant" and "orderGrudging" or "orderYes") end
    return response("applied", "Received; accepted " .. kind .. ". Action completion has not been inferred.")
end
return M
