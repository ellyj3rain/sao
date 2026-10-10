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
    if selected ~= id then nextSample = 0 end
    selected = id
    return true
end
function O.panel(panelId, personId, visible)
    if panelId ~= "person-inspection" or type(visible) ~= "boolean" or not O.validatePerson(personId) then return false end
    if not SAO.Inspect or not SAO.Inspect.show or not SAO.Inspect.hide then return false end
    local ok = visible and SAO.Inspect.show(personId) or (not visible and SAO.Inspect.hide())
    if ok ~= true then return false end
    if selected ~= personId then nextSample = 0 end
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
            local revision = tostring(math.max(1,
                math.floor(tonumber(process.revision) or 1)))
            local enacted = process.procedures and process.procedures[revision]
            if enacted then
                row(s, "Enacted procedure", tostring(enacted.status)
                    .. (enacted.objective and " / " .. tostring(enacted.objective)
                        or ""))
                if enacted.revisionNeeded then
                    row(s, "Revision needed",
                        tostring(enacted.revisionNeeded.stepId) .. " / "
                        .. tostring(enacted.revisionNeeded.reason))
                end
                for _, stepId in ipairs(enacted.order or {}) do
                    local step = enacted.steps and enacted.steps[stepId]
                    if step then
                        local contributors, claimants, ownClaim = 0, {}, nil
                        for actorId in pairs(step.contributions or {}) do
                            contributors = contributors + 1
                        end
                        for actorId, claim in pairs(step.claims or {}) do
                            if claim.status == "claimed"
                                or claim.status == "attempting"
                                or claim.status == "completed" then
                                claimants[#claimants + 1] = actorId
                            end
                            if actorId == id then ownClaim = claim end
                        end
                        table.sort(claimants)
                        local detail = tostring(step.status)
                        if enacted.cooperative then
                            detail = detail .. " / "
                                .. tostring(step.role or step.verb) .. " / "
                                .. tostring(step.domain or "action")
                            if step.posture then
                                detail = detail .. " / " .. tostring(step.posture)
                            end
                            local target = step.target or {}
                            if tonumber(target.x) and tonumber(target.y) then
                                detail = detail .. " / target "
                                    .. tostring(target.x) .. "," .. tostring(target.y)
                            end
                            if (step.minActors or 1) > 1 or contributors > 0 then
                                detail = detail .. " / " .. tostring(contributors)
                                    .. "/" .. tostring(step.minActors or 1)
                            end
                            if #claimants > 0 then
                                detail = detail .. " / "
                                    .. table.concat(claimants, ", ")
                            end
                        end
                        row(s, "Actual: " .. tostring(step.verb), detail)
                        if ownClaim then
                            row(s, "My role: " .. tostring(step.role or step.verb),
                                tostring(ownClaim.status))
                        end
                    end
                end
            end
            local plans = process.privatePlans and process.privatePlans[id]
            local plan = plans and plans[revision]
            if plan then
                row(s, "Personal next step", plan.intendedStepId or "No next step")
                for _, stepId in ipairs(enacted and enacted.order or {}) do
                    local belief = plan.beliefs and plan.beliefs[stepId]
                    if belief then row(s, "Belief: " .. tostring(belief.verb),
                        tostring(belief.status)) end
                end
            end
            local events = process.events or {}
            for eventIndex = math.max(1, #events - 5), #events do
                if #s.rows >= 48 then break end
                local event = events[eventIndex]
                if event then
                    local eventDetail = tostring(event.kind or "event")
                        .. " / " .. tostring(event.actorId or "unknown")
                    local data = event.detail or {}
                    if data.stepId then
                        eventDetail = eventDetail .. " / " .. tostring(data.stepId)
                    elseif data.reason then
                        eventDetail = eventDetail .. " / " .. tostring(data.reason)
                    elseif data.response then
                        eventDetail = eventDetail .. " / " .. tostring(data.response)
                    end
                    row(s, "Recent procedure event", eventDetail)
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
local function lifeProfile(id, rec)
    local s = section("life-profile", "Life and practical background",
        "SAO age, condition and habit owners",
        "Durable facts that shape memory, learning and physical choices")
    local age = SAO.History and SAO.History.ageOf and SAO.History.ageOf(id) or nil
    if finite(age) then
        row(s, "Age", math.floor(age))
        local stage = SAO.History.stageOf and SAO.History.stageOf(age) or nil
        if stage then row(s, "Life stage", tostring(stage)) end
    end
    if rec.occupation then row(s, "Prior occupation", tostring(rec.occupation)) end
    if rec.designation then row(s, "Current designation", tostring(rec.designation)) end
    local conditions = SAO.Conditions and SAO.Conditions.of and SAO.Conditions.of(id) or {}
    local habits = SAO.Habits and SAO.Habits.of and SAO.Habits.of(id) or {}
    row(s, "Conditions", #conditions > 0 and table.concat(conditions, ", ") or "None recorded")
    row(s, "Habits", #habits > 0 and table.concat(habits, ", ") or "None recorded")
    if SAO.History and SAO.History.literacyOf then
        row(s, "Literacy", tostring(SAO.History.literacyOf(id)))
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
local function horseState(id, rec, body)
    local s = section("horse", "Horse and mounted travel",
        "SAO animal integration", "Native animal, durable relation and current route")
    local mounted = SAO.Animals and SAO.Animals.mountedHorse
        and SAO.Animals.mountedHorse(body) or nil
    local job = SAO.Animals and SAO.Animals.travelJobs
        and SAO.Animals.travelJobs[id] or nil
    local durable = rec.horseMount
    if mounted then
        row(s, "Mounted horse", tostring(mounted.animalId))
        local ok, stamina = pcall(function()
            local Stamina = require("HorseMod/Stamina")
            return Stamina.get(mounted.animal)
        end)
        if ok and finite(stamina) then row(s, "Horse stamina", string.format("%.1f", stamina)) end
    elseif durable and durable.animalId then
        row(s, "Remembered horse", tostring(durable.animalId))
        row(s, "Relation state", durable.active and "Awaiting physical reconciliation" or "Dismounted")
    end
    if job then
        row(s, "Travel phase", tostring(job.phase))
        row(s, "Destination", string.format("%.1f, %.1f, %d",
            job.goal.x, job.goal.y, job.goal.z))
        if job.waypointX and job.waypointY then
            row(s, "Native route waypoint", string.format("%.1f, %.1f",
                job.waypointX, job.waypointY))
        end
    end
    if not mounted and not job and not (durable and durable.animalId) then
        s.message = "No known horse relation or current mounted travel"
    end
    return s
end
local function mobileHousehold(id)
    local s = section("mobile-household", "Moving place and household",
        "SAO mobile household owner",
        "Native vehicle, interior transition, occupants, stores and towing continuity")
    local view = SAO.MobileHousehold and SAO.MobileHousehold.snapshot
        and SAO.MobileHousehold.snapshot(id) or nil
    if not view then
        s.message = "Not currently inside a known mobile place"
        return s
    end
    row(s, "Place", tostring(view.id) .. " / " .. tostring(view.kind))
    row(s, "Physical state", tostring(view.state) .. " / " .. tostring(view.motion))
    row(s, "External anchor", string.format("%.1f, %.1f, %d",
        tonumber(view.x) or 0, tonumber(view.y) or 0, tonumber(view.z) or 0))
    if finite(view.speedKmh) then
        row(s, "Speed", string.format("%.1f km/h", view.speedKmh))
    end
    row(s, "Observed occupants", view.occupants or 0)
    row(s, "Native stored items", view.itemCount or 0)
    if finite(view.materialWeight) then
        row(s, "Observed stored weight", string.format("%.2f", view.materialWeight))
    end
    row(s, "Material revision", view.materialRevision or 0)
    if finite(view.lastObservedAtHours) then
        row(s, "Place last observed", string.format("%.2f h", view.lastObservedAtHours))
    end
    if finite(view.materialObservedAtHours) then
        row(s, "Stores last observed", string.format("%.2f h", view.materialObservedAtHours))
    end
    if view.towing then row(s, "Towing", view.towing) end
    if view.towedBy then row(s, "Towed by", view.towedBy) end
    row(s, "Recorded transitions", view.transitions or 0)
    if (view.failures or 0) > 0 then row(s, "Recorded failures", view.failures) end
    return s
end
local function conflictText(value, fallback)
    return type(value) == "string" and #value > 0 and text(value):gsub("%-", " ")
        or fallback
end
local function conflictList(values, maximum)
    local out = {}
    if type(values) == "table" then
        for index = 1, maximum do
            local value = conflictText(values[index])
            if value then out[#out + 1] = value end
        end
    end
    return #out > 0 and table.concat(out, "; ") or nil
end
local function conflictPlanning(s, id)
    local getter = SAO.ProceduralPlanning and SAO.ProceduralPlanning.conflictSnapshot
    if type(getter) ~= "function" then return false end
    local ok, view = pcall(getter, id)
    if ok and view == nil then
        row(s, "Conflict appraisal", "No conflict appraisal recorded")
        return false
    end
    if not ok or type(view) ~= "table" or view.schema ~= 1 or view.actorId ~= id then
        row(s, "Conflict appraisal", "Recorded conflict appraisal unavailable")
        return false
    end
    row(s, "Conflict appraisal", conflictText(view.status, "Recorded")
        .. (finite(view.atHours) and " at game hour " .. tostring(view.atHours) or " / time unavailable"))
    local threat = type(view.threat) == "table" and view.threat or {}
    local basis = conflictText(threat.kind, "Threat kind unknown") .. " / "
        .. conflictText(threat.source, "acquisition source unavailable")
    if finite(threat.distance) and threat.distance >= 0 then
        basis = basis .. " / believed distance " .. string.format("%.1f", threat.distance) .. " tiles"
    end
    row(s, "Threat belief", basis)
    row(s, "Intended response", conflictText(view.kind, "No response recorded"))
    row(s, "Response reason", conflictText(view.reason, "No rationale recorded"))
    local admission = type(view.admission) == "table" and view.admission or nil
    row(s, "Native admission", admission and conflictText(admission.owner, "Execution owner unavailable")
        .. (finite(admission.atHours) and " admitted at game hour " .. tostring(admission.atHours) or " / admission time unavailable")
        or "No native attempt admission recorded")
    local outcome = type(view.lastOutcome) == "table" and view.lastOutcome or nil
    if outcome then
        row(s, "Last native attempt", conflictText(outcome.kind, "Attempt") .. " / "
            .. conflictText(outcome.status, "result unavailable")
            .. (finite(outcome.atHours) and " at game hour " .. tostring(outcome.atHours) or " / time unavailable"))
        row(s, "Attempt detail", conflictText(outcome.reason, "No native result detail recorded"))
        row(s, "Threat after attempt", "Requires fresh perception; the attempt result does not establish that the threat is gone")
    else
        row(s, "Last native attempt", "No native attempt result recorded")
    end
    local alternatives = type(view.alternatives) == "table" and view.alternatives or {}
    for index = 1, 4 do
        local alternative = alternatives[index]
        if type(alternative) == "table" then
            local label = tostring(index)
            local status = alternative.selected == true and "selected"
                or alternative.continuing == true and "continuing"
                or alternative.available == true and "available"
                or alternative.available == false and "unavailable" or "availability unknown"
            row(s, "Alternative " .. label, conflictText(alternative.kind, "Unspecified response") .. " / " .. status)
            row(s, "Reason " .. label, conflictText(alternative.reason)
                or conflictList(alternative.reasons, 3) or "No rationale recorded")
            local objections = conflictList(alternative.objections, 3)
            if objections then row(s, "Objection " .. label, objections) end
            local effects = type(alternative.expectedEffects) == "table" and alternative.expectedEffects or {}
            local expectations = {}
            for effectIndex = 1, 2 do
                local effect = effects[effectIndex]
                if type(effect) == "table" then
                    expectations[#expectations + 1] = conflictText(effect.concept, "Effect unknown")
                        .. " (" .. (effect.status == "possible" and "possible" or "unresolved") .. ")"
                        .. (conflictText(effect.basis) and ": " .. conflictText(effect.basis) or "")
                end
            end
            if #expectations > 0 then row(s, "Expected effect " .. label, table.concat(expectations, "; ")) end
        end
    end
    return true
end
local function planning(id, rec)
    local s = section("planning", "Purposes and next steps",
        "ProceduralPlanning person-private store",
        "Maintained intent, blockers and model interpretations")
    local hasConflict = conflictPlanning(s, id)
    local leisure = rec and rec.leisureDecision
    if type(leisure) == "table" then
        row(s, "Leisure decision hour", leisure.atHours or "unknown")
        row(s, "Leisure selection status", leisure.status or "unknown")
        row(s, "Selected leisure action", leisure.selected or "No available selection")
        for index, alternative in ipairs(leisure.alternatives or {}) do
            if index > 2 then break end
            row(s, "Leisure alternative " .. tostring(index),
                tostring(alternative.kind or "unknown") .. " / "
                    .. tostring(alternative.itemType or "unknown item") .. " ["
                    .. tostring(alternative.itemKey or "unknown identity") .. "]")
        end
        for index, model in ipairs(leisure.interpretations and leisure.interpretations.models or {}) do
            if index > 2 then break end
            row(s, "Leisure model " .. tostring(index), tostring(model.modelId or "unknown")
                .. " selects " .. tostring(model.selected or "No available selection"))
        end
        row(s, "Leisure evidence boundary", "Decision and admission are separate from completed use or shared participation")
    end
    local view = SAO.ProceduralPlanning and SAO.ProceduralPlanning.snapshot
        and SAO.ProceduralPlanning.snapshot(id) or nil
    if not view then
        s.status = (hasConflict or type(leisure) == "table") and "available" or "unavailable"
        s.message = hasConflict and "No other maintained planning state" or "No maintained planning state"
        return s
    end
    row(s, "Remembered spatial facts", view.spatialFacts or 0)
    row(s, "Practiced domains", view.practiceDomains or 0)
    local queued = view.queuedPurposes or {}
    for index, purpose in ipairs(queued) do
        if index > 4 then break end
        row(s, "Deferred purpose " .. tostring(index), tostring(purpose.id or "unknown")
            .. " / " .. tostring(purpose.objective or purpose.key or "unknown purpose")
            .. " / " .. tostring(purpose.status or "unknown")
            .. " / " .. tostring(purpose.reason or "No reason recorded"))
    end
    if #queued > 4 then row(s, "Other deferred purposes", #queued - 4) end
    local suspended = view.suspendedLeisure
    if type(suspended) == "table" then
        for index, purpose in ipairs(suspended.purposes or {}) do
            if index > 4 then break end
            row(s, "Deferred leisure " .. tostring(index), tostring(purpose.id or "unknown")
                .. " / " .. tostring(purpose.activity or "unknown activity")
                .. " / " .. tostring(purpose.status or "unknown")
                .. " / " .. tostring(purpose.reason or "No reason recorded"))
        end
        if #(suspended.purposes or {}) > 4 then
            row(s, "Other deferred leisure", #suspended.purposes - 4)
        end
        if (tonumber(suspended.omitted) or 0) > 0 then
            row(s, "Older leisure records omitted", suspended.omitted)
        end
    end
    local placement = rec and rec.recoveryPlacement
    if placement then
        row(s, "Resting place", tostring(placement.status or "unknown") .. " / "
            .. tostring(placement.reason or "No reason recorded"))
    end
    local placeCheck = rec and rec.recoveryPlaceObservation
    if placeCheck then
        row(s, "Last recovery check", tostring(placeCheck.status or "unknown")
            .. " at game hour " .. tostring(placeCheck.atHours or "unknown"))
        if placeCheck.reason then row(s, "Recovery check detail", placeCheck.reason) end
        row(s, "Place candidates", tostring(placeCheck.acceptedCount or 0)
            .. " usable from " .. tostring(placeCheck.offeredCount or 0) .. " local offers")
        local diagnostic = placeCheck.diagnostics or {}
        if diagnostic.nativeAsleep ~= nil or diagnostic.nativeOnBed ~= nil then
            row(s, "Observed recovery posture", "Asleep: " .. tostring(diagnostic.nativeAsleep)
                .. " / on bed: " .. tostring(diagnostic.nativeOnBed))
        end
        if diagnostic.visibleBedParts ~= nil then
            row(s, "Observed bed check", tostring(diagnostic.visibleBedParts)
                .. " visible parts / " .. tostring(diagnostic.admissibleBeds or 0) .. " usable beds")
            row(s, "Ground check", tostring(diagnostic.admissibleGround or 0) .. " clear places / "
                .. tostring(diagnostic.groundRejectedVisibility or 0) .. " visibility refusals / "
                .. tostring(diagnostic.groundRejectedClearance or 0) .. " clearance refusals")
        end
        for index, rejection in ipairs(diagnostic.bedRejections or {}) do
            if index > 4 then break end
            row(s, "Bed check " .. tostring(index), tostring(rejection.sprite or rejection.key or "Observed bed")
                .. " / " .. tostring(rejection.reason or "Unspecified refusal"):gsub("%-", " "))
        end
    end
    if view.study then
        local reading = view.study
        local readingPhase = tostring(reading.phase or "unconfirmed")
        if reading.contentKind == "written-note" then
            row(s, "Reading", "Written notes / " .. readingPhase)
            row(s, "Text exposure", reading.exposureCompleted == true
                and "Read; understanding unknown"
                or (tonumber(reading.progress) or 0) > 0
                    and "Reading underway; completion unconfirmed"
                    or "No reading progress observed")
        else
            row(s, reading.kind == "leisure" and "Reading" or "Study",
                tostring(reading.subject or reading.fullType or "Recorded book") .. " / "
                .. readingPhase)
            if tonumber(reading.totalPages) and tonumber(reading.totalPages) > 0 then
                row(s, "Reading progress", tostring(reading.pages or 0) .. " of "
                    .. tostring(reading.totalPages) .. " pages")
            else
                row(s, "Reading progress", (tonumber(reading.progress) or 0) > 0
                    and "Native action progress observed" or "No native action progress observed")
            end
        end
        if reading.reason then row(s, "Reading detail", reading.reason) end
    end
    for index = #(view.purposes or {}), 1, -1 do
        local purpose = view.purposes[index]
        row(s, "Purpose", tostring(purpose.objective) .. " / "
            .. tostring(purpose.status))
        if purpose.inquiry then
            local inquiry, connection = purpose.inquiry, {}
            row(s, "Looking for", tostring(inquiry.desiredConcept or "an unresolved means")
                .. " for " .. tostring(inquiry.goal or "the maintained purpose"))
            for index, edge in ipairs(inquiry.path and inquiry.path.roots or {}) do
                if index > 6 then break end
                connection[#connection + 1] = tostring(edge.from):gsub("%-", " ") .. " "
                    .. tostring(edge.relation):gsub("%-", " ") .. " "
                    .. tostring(edge.into):gsub("%-", " ")
            end
            if #connection > 0 then row(s, "Expected connection", table.concat(connection, "; ")) end
            row(s, "Knowledge status", "Personal expectation; local availability still requires observation and checking")
            if #(inquiry.path and inquiry.path.missing or {}) > 0 then
                row(s, "Still unknown", table.concat(inquiry.path.missing, ", "))
            end
        end
        if purpose.resourceOutcome then
            local goal, progress = purpose.resourceOutcome, purpose.outcomeProgress or {}
            local unit = goal.category == "food" and "food items" or "water units"
            local stock = finite(progress.held) and tostring(progress.held) or "Not checked"
            if finite(progress.held) and progress.coverage == "first-128-native-private-carried-items-lower-bound" then
                stock = "At least " .. stock
            end
            row(s, "Goal source", "Assigned for this trial; the survivor chooses the means")
            row(s, "Supplies secured", stock .. " / " .. tostring(goal.target) .. " " .. unit)
            if goal.deadlineAfterHours then
                row(s, "Goal time limit", tostring(goal.deadlineAfterHours) .. " game hours from assignment")
            end
            if purpose.resolution then row(s, "Goal outcome", purpose.resolution) end
        end
        if purpose.nextStep then
            row(s, "Next step", tostring(purpose.nextStep) .. " / "
                .. tostring(purpose.nextOwner or "unowned"))
        end
        if #(purpose.blockers or {}) > 0 then
            row(s, "Blocked by", table.concat(purpose.blockers, ", "))
        end
        if purpose.resourceCategory then
            local demand, capacity = purpose.demand or {}, purpose.capacity or {}
            row(s, "Resource goal", tostring(purpose.resourceCategory) .. " / pressure "
                .. tostring(math.floor((tonumber(demand.pressure) or 0) * 100)) .. "% / usable food "
                .. tostring(demand.ownedReady or "unknown") .. " / raw food "
                .. tostring(demand.ownedRaw or "unknown") .. " / water vessels "
                .. tostring(demand.ownedWater or "unknown"))
            local sequence = {}
            for stepIndex, step in ipairs(purpose.sequence or {}) do
                if stepIndex > 4 then break end
                local verb = step.owner == "Cooking" and "prepare food"
                    or step.owner == "SAO.ResourceProduction" and step.productionKind == "plumb-fixture" and "connect water fixture"
                    or step.owner == "SAO.ResourceProduction" and "fill water vessel" or step.verb
                sequence[#sequence + 1] = tostring(verb) .. " (" .. tostring(step.status) .. ")"
            end
            row(s, "Work sequence", #sequence > 0 and table.concat(sequence, " > ") or "No known executable route")
            row(s, "Plan reason", purpose.rationale or "Current resource pressure")
            local practical = purpose.resourceCategory == "food" and "Cooking" or "Strength"
            row(s, "Personal capacity", practical .. " level " .. tostring(capacity.skills and capacity.skills[practical] or "unknown")
                .. " / fatigue " .. (finite(capacity.fatigue) and tostring(math.floor(capacity.fatigue * 100)) .. "%" or "unknown")
                .. " / accepted commitments " .. tostring(#(capacity.commitments or {})))
            row(s, "Potential helpers", tostring(#(purpose.contacts or {})) .. " personally known; capacity and assent unconfirmed")
            row(s, "Uncertainty", purpose.uncertainty or demand.uncertainty or "Future access and yield are unconfirmed")
            local failure = purpose.routeFailures and purpose.routeFailures[#purpose.routeFailures]
            if failure then
                row(s, "Route experience", tostring(failure.reason) .. " / " .. tostring(failure.attempts)
                    .. " unsuccessful attempts / reconsider after game hour " .. tostring(failure.retryAt))
            end
            local labor, dimensions = purpose.labor or {}, {}
            for _, question in ipairs({ {"neededNow", "need"}, {"capableActors", "people"},
                {"timeClaims", "time claims"}, {"materialsAndSpace", "material and space"},
                {"openProjects", "projects"}, {"groupValues", "group requirements"},
                {"lowPressureWish", "personal wishes"}, {"slack", "slack"} }) do
                dimensions[#dimensions + 1] = question[2] .. ": "
                    .. tostring(labor[question[1]] and labor[question[1]].status or "unknown")
            end
            row(s, "Labor assessment", table.concat(dimensions, "; "))
            if capacity.timeEvidence then
                local time = capacity.timeEvidence
                row(s, "Observed work duration", tostring(time.samples) .. " completed Cooking samples / "
                    .. tostring(time.observedMinimumHours) .. " to " .. tostring(time.observedMaximumHours)
                    .. " game hours; future duration is uncertain")
            end
        end
        local interpretations = purpose.interpretations
        for _, model in ipairs(interpretations and interpretations.models or {}) do
            row(s, tostring(model.modelId) .. " model",
                tostring(model.selected) .. " / "
                .. tostring(model.interpretation))
        end
        if interpretations and interpretations.disagreement then
            row(s, "Model disagreement", "The models prefer different next routes")
        end
    end
    if #(view.purposes or {}) == 0 and not hasConflict then s.message = "No maintained purpose yet" end
    return s
end
local function pressureFor(id)
    local agent = SAO.Controller and SAO.Controller.agents and SAO.Controller.agents[id]
    local pressure = section("pressure", "Pressure and recorded reason", "Controller", "Most recent decision receipt")
    if agent and agent.pressure then scalarRows(pressure, agent.pressure, "", 0)
    else pressure.status = "unavailable"; pressure.message = "No active pressure receipt" end
    return pressure
end
local richSections = {
    { "life-profile", "Life and practical background" }, { "medication", "Substance effects" },
    { "cooking", "Food preparation" }, { "horse", "Horse and mounted travel" },
    { "mobile-household", "Moving place and household" }, { "planning", "Purposes and next steps" },
    { "inventory", "Carried inventory" }, { "processes", "Reception, responses and work" },
    { "cognition", "Competing cognition" }
}
local function samplePerson(id, rec, body, rich)
    -- All feeds retain current bounded physical/execution facts. The inspector
    -- owns expensive cognitive, inventory and global-process projection; camera
    -- switching alone does not rebuild every person's internal perspective.
    local out = { sections = { needs(body), attention(rec, body), pressureFor(id),
        currentAction(id, body), sourceWork(id, rec) }, events = {} }
    if rich then
        for _, value in ipairs({ lifeProfile(id, rec), medication(rec), preparation(id, rec),
                horseState(id, rec, body), mobileHousehold(id), planning(id, rec), inventory(body), processes(id) }) do
            out.sections[#out.sections + 1] = value
        end
        if SAO.Cognition and SAO.Cognition.snapshot then out.cognition = SAO.Cognition.snapshot(id) end
    else
        -- Do not retain an older rich row under this snapshot's newer clock.
        -- Existing consumers carry section status/message but one source clock.
        for _, descriptor in ipairs(richSections) do
            out.sections[#out.sections + 1] = section(descriptor[1], descriptor[2],
                "Selected inspection", "Not sampled", "unavailable",
                "Detailed state was not requested for this person")
        end
    end
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
        local sampleSelected = selected and all[selected] and selected or nil
        if sampleSelected then ids[1] = sampleSelected end
        for id, rec in pairs(all) do
            local body = bodyFor(id, rec)
            if body then
                represented[id] = body
                if id ~= sampleSelected then
                    if #ids < MAX_PEOPLE then ids[#ids + 1] = id else omitted = omitted + 1 end
                end
            end
        end
        local people = {}
        for _, id in ipairs(ids) do people[id] = samplePerson(id, all[id], represented[id], id == sampleSelected) end
        sequence = sequence + 1
        return { sequence = sequence, capturedAtUnixMs = nowMs, worldHours = worldHours,
            status = "available", message = "Current bodies and recorded execution facts; no decision or perception rerun",
            omittedPeople = omitted, omittedEvents = dropped, selectedPersonId = sampleSelected, people = people }
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
