-- SAO_PathogenEvents - the living county's pathogen seam.
--
-- SAO emits the events it owns: an infection, a death, and a turn.
-- ZAO, when present, turns those events into pathogen state. The
-- elapsed-years pass then derives knowledge from actual proximity:
-- a living record meets a carrier, sees what that carrier is, and
-- only then learns.

SAO = SAO or {}
SAO.PathogenEvents = SAO.PathogenEvents or {}
local Events = SAO.PathogenEvents

local ENCOUNTER_RANGE = 3

-- `next` is not in this engine's Lua, so an emptiness probe walks
-- and stops at the first entry.
local function hasEntries(t)
    if type(t) ~= "table" then return false end
    for _ in pairs(t) do return true end
    return false
end

local function recordOf(personId, data)
    if type(data) == "table" and type(data.record) == "table" then
        return data.record
    end
    return SAO.Identity and SAO.Identity.get(personId) or nil
end

function Events.emit(kind, personId, day, data)
    personId = tostring(personId or "")
    local record = recordOf(personId, data)
    kind = tostring(kind or "")
    local atHours = nil
    if type(data) == "table" then atHours = tonumber(data.atHours) end
    if atHours == nil and tonumber(day) then atHours = tonumber(day) * 24.0 end
    local handled = false

    -- The pathogen owner moves first.  Neuro then observes the resulting
    -- terminal state at the same exact event time, while its durable cursor
    -- integrates the facts that were active immediately before this event.
    if ZAO and ZAO.Pathogen and ZAO.StateStore then
        if kind == "infection" then
            handled = ZAO.Pathogen.begin(
                personId, "infected", day, "infection", record, atHours) ~= nil
        elseif kind == "death" then
            local terminal = record and record.turnedDormant
                and "turned" or "dead"
            handled = ZAO.Pathogen.begin(
                personId, terminal, day, "death", record, atHours) ~= nil
        elseif kind == "turn" then
            handled = ZAO.Pathogen.begin(
                personId, "turned", day, "turn", record, atHours) ~= nil
        elseif kind == "recovery" then
            handled = ZAO.Pathogen.begin(
                personId, "living", day, "recovery", record, atHours) ~= nil
        end
    end

    local observed = false
    if record and SAO.Neuro and SAO.Neuro.observe
        and (kind == "infection" or kind == "death" or kind == "turn"
            or kind == "recovery") then
        local ok = pcall(SAO.Neuro.observe, record, atHours,
            "pathogen-" .. kind)
        observed = ok == true
    end
    return handled or observed
end

function Events.observe(personId, form, performance, source, day)
    if not (SAO and SAO.Adaptation and SAO.Adaptation.observe) then
        return false
    end
    return SAO.Adaptation.observe(
        personId, form, performance, source, day)
end

function Events.tell(fromId, toId, day)
    if not (SAO and SAO.Adaptation and SAO.Adaptation.tell) then
        return false
    end
    return SAO.Adaptation.tell(fromId, toId, day)
end

local function carrierOf(id, record, hour)
    if not (ZAO and ZAO.State) then return nil end
    local saved = ZAO.StateStore and ZAO.StateStore.read(id) or nil
    local terminal = saved and saved.terminalState or nil
    local hasMutation = saved
        and (saved.currentForm ~= nil and saved.currentForm ~= "none"
            or hasEntries(saved.attributeMutations))
    local pathogenActive = record.dead or record.turnedDormant
        or record.knoxInfected
        or terminal == "afflicted" or terminal == "crossed"
        or (terminal == "living" and hasMutation)
    if not pathogenActive then return nil end

    local state = ZAO.State.of(record, hour)
    if not state then return nil end
    return {
        id = id,
        x = record.x,
        y = record.y,
        state = state,
    }
end

local function snapshot(state)
    return {
        terminalState = state.terminalState,
        currentForm = state.currentForm,
        formPerformance = state.formPerformance,
        decayState = state.decayState,
        attributeMutations = state.attributeMutations,
        source = state.source,
        lastEvent = state.history and state.history[#state.history] or nil,
    }
end

local function sourceOwnsActor(id)
    if SAO.WorldSources and SAO.WorldSources.ownsActor then
        return SAO.WorldSources.ownsActor(id) == true
    end
    return false
end

function Events.simulateDay(day)
    if not (ZAO and ZAO.State and SAO.Identity) then
        return false
    end

    day = tonumber(day) or 0
    local hour = day * 24.0
    local carriers = {}

    if ZAO.Pathogen and ZAO.Pathogen.advance then
        for id, _ in pairs(SAO.Identity.all()) do
            if ZAO.StateStore and ZAO.StateStore.read(id) then
                ZAO.Pathogen.advance(id, day)
            end
        end
    end

    for id, record in pairs(SAO.Identity.all()) do
        local carrier = carrierOf(id, record, hour)
        if carrier then
            carriers[#carriers + 1] = carrier
        end
    end

    if #carriers == 0 then return false end

    local observations = 0
    for id, record in pairs(SAO.Identity.all()) do
        if not record.dead and not SAO.Body.hasRepresentation(id)
            and not sourceOwnsActor(id) then
            for _, carrier in ipairs(carriers) do
                if carrier.id ~= id then
                    local dx = (tonumber(record.x) or 0)
                        - (tonumber(carrier.x) or 0)
                    local dy = (tonumber(record.y) or 0)
                        - (tonumber(carrier.y) or 0)
                    if dx * dx + dy * dy
                        <= ENCOUNTER_RANGE * ENCOUNTER_RANGE then

                        if carrier.state.currentForm ~= "none" then
                            Events.observe(
                                id,
                                carrier.state.currentForm,
                                carrier.state.formPerformance,
                                "lived",
                                day)
                            observations = observations + 1
                        end

                        break
                    end
                end
            end

            local state = ZAO.State.of(record, hour)
            if state then
                record.pathogenState = snapshot(state)
            end
        end
    end

    return observations > 0
end

return Events
