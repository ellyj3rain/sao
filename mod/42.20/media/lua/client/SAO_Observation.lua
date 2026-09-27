-- Read-only operator inspection. Runtime buffers contain scalars, never bodies.
SAO = SAO or {}
SAO.Observation = SAO.Observation or {}
local O = SAO.Observation
local MAX_PEOPLE, MAX_EVENTS, MAX_EVENT_PEOPLE = 16, 24, 64
local enabled, selected, sequence, nextSample = false, nil, 0, 0
local histories, historyOrder, eventSequence, dropped = {}, {}, 0, 0
local cached = { sequence = 0, capturedAtUnixMs = 0, worldHours = 0,
    status = "unavailable", message = "Inspection has not sampled", people = {},
    omittedPeople = 0, omittedEvents = 0 }

local function finite(v) return type(v) == "number" and v == v and math.abs(v) < math.huge end
local function text(v, limit)
    if type(v) ~= "string" and type(v) ~= "number" and type(v) ~= "boolean" then return "unavailable" end
    local s = tostring(v)
    return #s > (limit or 384) and s:sub(1, (limit or 384) - 3) .. "..." or s
end
local function records()
    local store = ModData and ModData.get and ModData.get("SurvivorAwareness_Records")
    return type(store) == "table" and store.records or {}
end
local function bodyFor(id, rec)
    local body = SAO.Body and SAO.Body.active and SAO.Body.active[id]
    if not body and rec and rec.bodyOwner then
        local owner = SAO.Communication and SAO.Communication.executionOwners
            and SAO.Communication.executionOwners[rec.bodyOwner]
        if owner and owner.bodyFor then body = owner.bodyFor(id, rec) end
    end
    if body and body:getCurrentSquare() ~= nil then return body end
end
local function clock()
    local ms, hours = getTimestampMs(), SAO.History.countyHours()
    if not finite(ms) or not finite(hours) then error("inspection clock unavailable") end
    return ms, hours
end
local function section(id, label, source, perspective, status, message)
    return { id = id, label = label, source = source, perspective = perspective,
        status = status or "available", message = message or "", rows = {} }
end
local function row(s, label, value)
    if #s.rows < 48 then s.rows[#s.rows + 1] = { label = text(label, 160), value = text(value) } end
end
local function scalarRows(s, value, prefix, depth)
    if type(value) ~= "table" then row(s, prefix, value); return end
    if depth > 2 then row(s, prefix, "Additional structured detail is not sampled"); return end
    for k, v in pairs(value) do
        if #s.rows >= 48 then return end
        if type(k) == "string" or type(k) == "number" then
            local label = prefix == "" and tostring(k) or prefix .. "." .. tostring(k)
            if type(v) == "table" then scalarRows(s, v, label, depth + 1)
            elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" then row(s, label, v) end
        end
    end
end

function O.isEnabled() return enabled end
function O.validatePerson(id)
    return enabled and type(id) == "string" and #id > 0 and #id <= 128 and records()[id] ~= nil
end
function O.select(id)
    if not O.validatePerson(id) then return false end
    selected = id
    return true
end
function O.panel(panelId, personId, visible)
    if panelId ~= "person-inspection" or type(visible) ~= "boolean" or not O.validatePerson(personId) then return false end
    if not SAO.Inspect or not SAO.Inspect.show or not SAO.Inspect.hide then return false end
    local ok = visible and SAO.Inspect.show(personId) or (not visible and SAO.Inspect.hide())
    if ok ~= true then return false end
    selected = personId
    return true
end
function O.cognition(opponentShare, opportunitiesPerHour, maxDepth)
    if not enabled or not SAO.Cognition or not SAO.Cognition.configure then return false end
    local applied = SAO.Cognition.configure(opponentShare, opportunitiesPerHour, maxDepth)
    if applied then nextSample = 0 end
    return applied == true
end
function O.nativePanel()
    return enabled and SAO.Inspect and SAO.Inspect.nativePanel and SAO.Inspect.nativePanel() or nil
end

-- Called only after an execution owner has produced the stated fact. A spoken
-- line records emission; nobody is inferred to have heard or answered it.
function O.record(id, source, stage, summary, correlationId)
    if not enabled or type(id) ~= "string" then return end
    local rec = records()[id]
    if not rec or (id ~= selected and not histories[id] and not bodyFor(id, rec)) then return end
    local ms, hours = clock()
    local history = histories[id]
    if not history then
        if #historyOrder >= MAX_EVENT_PEOPLE then
            local removed = table.remove(historyOrder, 1)
            dropped = dropped + #histories[removed]; histories[removed] = nil
        end
        historyOrder[#historyOrder + 1] = id
        history = {}; histories[id] = history
    end
    eventSequence = eventSequence + 1
    if #history >= MAX_EVENTS then table.remove(history, 1); dropped = dropped + 1 end
    history[#history + 1] = { id = "observation-" .. eventSequence, capturedAtUnixMs = ms,
        worldHours = hours, source = text(source, 160), stage = text(stage, 128),
        summary = text(summary, 1024), actorId = id,
        correlationId = correlationId and text(correlationId, 128) or nil }
end

local function needs(body)
    local s = section("needs", "Current needs", "Native body", "Current physical state")
    if not body then s.status = "unavailable"; s.message = "No loaded body; native needs were not sampled"; return s end
    local raw = tostring(SAOJavaBridge:getNeeds(body))
    for _, field in ipairs({ {"h", "Hunger"}, {"t", "Thirst"}, {"f", "Fatigue"},
        {"e", "Endurance"}, {"n", "Nicotine withdrawal"} }) do
        local number = tonumber(raw:match(field[1] .. "=([%d%.%-]+)"))
        if not finite(number) then error("native needs missing " .. field[1]) end
        row(s, field[2], string.format("%.4f", number))
    end
    local ok, health = pcall(function()
        local damage = body:getBodyDamage()
        return damage and damage:getOverallBodyHealth()
    end)
    row(s, "Health (%)", ok and finite(health) and health >= 0 and health <= 100
        and string.format("%.2f", health) or "unavailable")
    return s
end
local function inventory(body)
    local s = section("inventory", "Carried inventory", "Native inventory containers", "Current physical state")
    if not body then s.status = "unavailable"; s.message = "No loaded body; carried items were not sampled"; return s end
    local pending, seen, count, bounded = { { container = body:getInventory(), depth = 0 } }, {}, 0, false
    while #pending > 0 and count < 128 do
        local current = table.remove(pending)
        if current.container and not seen[current.container] then
            seen[current.container] = true
            local items = current.container:getItems()
            for i = 0, items:size() - 1 do
                if count >= 128 then bounded = true; break end
                local item = items:get(i); count = count + 1
                row(s, item:getFullType(), item:getName() .. " [id " .. tostring(item:getID()) .. "]")
                if instanceof(item, "InventoryContainer") then
                    if current.depth < 16 then
                        pending[#pending + 1] = { container = item:getInventory(), depth = current.depth + 1 }
                    else bounded = true end
                end
            end
        end
    end
    bounded = bounded or #pending > 0 or count > #s.rows
    s.message = tostring(count) .. " items read" .. (bounded and "; displayed inventory is bounded" or "")
    if count == 0 then s.message = "No carried items in the sampled native containers" end
    return s
end
local function currentAction(id, body)
    local s = section("actions", "Current action", "Controller, Locomotion and native timed-action queue", "Execution owners")
    local agent = SAO.Controller and SAO.Controller.agents and SAO.Controller.agents[id]
    row(s, "Controller state", agent and agent.state or "No active controller")
    local job = SAO.Locomotion and SAO.Locomotion.jobs and SAO.Locomotion.jobs[id]
    if job then
        row(s, "Movement", job.done and ("Terminal: " .. tostring(job.result)) or "Executing")
        row(s, "Native movement verdict", job.lastVerdict or "not reported")
        if job.goal then row(s, "Destination", tostring(job.goal.x) .. ", " .. tostring(job.goal.y) .. ", " .. tostring(job.goal.z)) end
    else row(s, "Movement", "No owned route") end
    local queue = body and ISTimedActionQueue and ISTimedActionQueue.queues and ISTimedActionQueue.queues[body]
    for i, action in ipairs(queue and queue.queue or {}) do
        if i > 8 then break end
        row(s, "Timed action " .. i, action.Type or "Unnamed native action")
        if action.action then row(s, "Native progress " .. i, action.action:getJobDelta()) end
    end
    return s
end
local function sourceWork(id, rec)
    local s = section("source-work", "Source use and latest result", "WorldSources durable action ledger", "Native action receipts")
    local store = ModData and ModData.get and ModData.get("SurvivorAwareness_WorldSources")
    if type(store) ~= "table" or store.schema ~= 6 then
        s.status = "unavailable"; s.message = "Source-action ledger unavailable"; return s
    end
    local function receiptRows(receipt, prefix)
        for _, key in ipairs({ "id", "reservationId", "status", "phase", "operation", "category", "itemType",
            "quantity", "requestedQuantity", "preRevision", "postRevision", "at", "resultAt", "detail", "nativeStatus" }) do
            if receipt[key] ~= nil then row(s, prefix .. "." .. key, receipt[key]) end
        end
    end
    -- pendingActionFor repairs pointers, so inspection reads the join directly
    -- and reports an invalid join without changing the actor or the ledger.
    local pointer = rec.worldSourceReservation
    local reservation = pointer and store.reservations and store.reservations[tostring(pointer)]
    if pointer then
        if reservation and reservation.actorId == id then receiptRows(reservation, "Source action")
        else row(s, "Source action", "Recorded pointer has no matching actor reservation") end
    else row(s, "Source action", "No recorded reservation pointer") end
    local latest = store.resultByActor and store.resultByActor[id]
    local receipt = latest and store.results and store.results[latest]
    if receipt and receipt.actorId == id then receiptRows(receipt, "Latest result")
    else row(s, "Latest result", "No retained receipt for this person") end
    return s
end
local function processes(id)
    local s = section("processes", "Reception, responses and work", "Organization durable process records", "Recorded stages for this person")
    local order, store = SAO.Organization and SAO.Organization.processOrder or {}, SAO.Organization and SAO.Organization.processes or {}
    local examined = 0
    for i = #order, 1, -1 do
        local process = store[order[i]]
        local participant = process and process.participants and process.participants[id]
        if participant then
            examined = examined + 1
            row(s, "Process " .. tostring(process.id), tostring(process.kind) .. " / " .. tostring(process.status))
            for rev, reception in pairs(participant.receptions or {}) do
                row(s, "Received revision " .. tostring(rev), "hour " .. tostring(reception.at) .. " via " .. tostring(reception.channel) .. " from " .. tostring(reception.fromId))
            end
            for rev, response in pairs(participant.responses or {}) do
                row(s, "Formed response " .. tostring(rev), tostring(response.response) .. " at hour " .. tostring(response.formedAt))
                row(s, "Response delivery " .. tostring(rev), response.delivered and ("Delivered at hour " .. tostring(response.deliveredAt)) or "Not recorded as delivered")
            end
            for rev, history in pairs(participant.responseHistory or {}) do
                for i = math.max(1, #history - 3), #history do
                    local prior = history[i]
                    row(s, "Prior response " .. tostring(rev), tostring(prior.response) .. " at hour " .. tostring(prior.formedAt)
                        .. (prior.delivered and "; delivered" or "; not recorded as delivered"))
                end
            end
            for key, commitment in pairs(process.commitments or {}) do
                if commitment.actorId == id then
                    row(s, "Commitment " .. tostring(key), commitment.status)
                    scalarRows(s, commitment.work or {}, "Work", 0)
                end
            end
            if examined >= 8 or #s.rows >= 48 then s.message = "Recent process detail is bounded"; break end
        end
    end
    if examined == 0 then s.message = "No recorded process participation in the current store" end
    return s
end
local function attention(rec, body)
    local s = section("attention", "Attention and movement", "Native body", "Current physical state")
    local ok, state = pcall(function() return body and SAOJavaBridge:orientationState(body) end)
    if not ok or type(state) ~= "table" then
        s.status, s.message = "unavailable", "No current physical attention sample"
        return s
    end
    row(s, "Response", state.active and "Turning toward a heard sound" or "No active sound response")
    if state.phase then row(s, "Phase", state.phase) end
    if state.active then
        row(s, "Body may turn", state.allowBodyTurn == true and "Yes" or "No")
        if finite(state.remainingSeconds) then row(s, "Seconds remaining", string.format("%.2f", state.remainingSeconds)) end
    end
    if SAO.Neuro then
        row(s, "Attention readiness", string.format("%.3f", SAO.Neuro.clarityOf(rec)))
        row(s, "Motor steadiness", string.format("%.3f", SAO.Neuro.motorSteadiness(rec)))
    end
    return s
end
local function medication(rec)
    local s = section("medication", "Substance effects", "Personal physiology", "Current physical state and recorded use")
    local effects = SAO.Pharmacology and SAO.Pharmacology.effects(rec)
    if not effects then s.message = "No recorded substance state"; return s end
    row(s, "Active effects", effects.active == true and "Yes" or "No")
    row(s, "Sedating", effects.sedating == true and "Yes" or "No")
    row(s, "Stimulating", effects.stimulating == true and "Yes" or "No")
    row(s, "Withdrawal", effects.withdrawal == true and "Yes" or "No")
    row(s, "Overload", effects.overload == true and "Yes" or "No")
    if #(effects.families or {}) > 0 then row(s, "Active families", table.concat(effects.families, ", ")) end
    local events = rec.pharmacology and rec.pharmacology.events or {}
    local first = math.max(1, #events - 5)
    for i = first, #events do
        local event = events[i]
        if event.kind == "use" then row(s, "Use at hour " .. tostring(event.atHours),
            tostring(event.itemType) .. ": " .. tostring(event.status)) end
    end
    return s
end
local function preparation(id, rec)
    local s = section("cooking", "Food preparation", "Native appliance and food", "Current work and recorded outcome")
    local state = SAO.Cooking and SAO.Cooking.snapshot(id)
    if state then
        row(s, "Stage", state.stage); row(s, "Food", state.itemType)
        row(s, "Heat progression observed", state.heatObserved == true and "Yes" or "No")
        if finite(state.cookingTime) then row(s, "Cooking progress", state.cookingTime) end
    else s.message = "No current food preparation" end
    local outcomes = rec.cookingOutcomes or {}
    local latest = outcomes[#outcomes]
    if latest then row(s, "Latest result", tostring(latest.status) .. ": " .. tostring(latest.detail)) end
    return s
end
local function samplePerson(id, rec, body)
    local agent = SAO.Controller and SAO.Controller.agents and SAO.Controller.agents[id]
    local pressure = section("pressure", "Pressure and recorded reason", "Controller", "Most recent decision receipt")
    if agent and agent.pressure then scalarRows(pressure, agent.pressure, "", 0)
    else pressure.status = "unavailable"; pressure.message = "No active pressure receipt" end
    local out = { sections = { needs(body), attention(rec, body), medication(rec), preparation(id, rec),
        inventory(body), pressure, currentAction(id, body), sourceWork(id, rec), processes(id) }, events = {} }
    if SAO.Cognition and SAO.Cognition.snapshot then out.cognition = SAO.Cognition.snapshot(id) end
    for _, event in ipairs(histories[id] or {}) do
        local copy = {}; for k, v in pairs(event) do copy[k] = v end
        out.events[#out.events + 1] = copy
    end
    return out
end
function O.capture(nowMs, worldHours)
    if not enabled then return cached end
    if not finite(nowMs) or not finite(worldHours) then error("inspection capture requires finite clocks") end
    if nowMs < nextSample then return cached end
    nextSample = nowMs + 1000
    local ok, result = pcall(function()
        local all, ids, represented, omitted = records(), {}, {}, 0
        if selected and all[selected] then ids[1] = selected end
        for id, rec in pairs(all) do
            local body = bodyFor(id, rec)
            if body then
                represented[id] = body
                if id ~= selected then
                    if #ids < MAX_PEOPLE then ids[#ids + 1] = id else omitted = omitted + 1 end
                end
            end
        end
        local people = {}
        for _, id in ipairs(ids) do people[id] = samplePerson(id, all[id], represented[id]) end
        sequence = sequence + 1
        return { sequence = sequence, capturedAtUnixMs = nowMs, worldHours = worldHours,
            status = "available", message = "Current bodies and recorded execution facts; no decision or perception rerun",
            omittedPeople = omitted, omittedEvents = dropped, selectedPersonId = selected, people = people }
    end)
    if ok then cached = result
    else
        -- A failed refresh retains the last successful timestamp and detail.
        cached.status = "failed"; cached.message = text(result, 1024)
    end
    return cached
end
function O.snapshot() return cached end
function O.detail(id) return cached.people and cached.people[id] end
local function refresh()
    if enabled then
        local ok, ms, hours = pcall(clock)
        if ok then O.capture(ms, hours)
        else cached.status = "failed"; cached.message = text(ms, 1024) end
    end
end
function O.enable() enabled = true; return true end
Events.OnTick.Add(refresh)
Events.OnTickEvenPaused.Add(refresh)
return O
