-- SAO_Adaptation - mutation knowledge learned from events.
--
-- A person learns a form only when they meet it or are told about it.
-- Repeated encounters deepen the knowledge, and the knowledge changes
-- how much pressure the form creates. Nothing is derived from a clock.

SAO = SAO or {}
SAO.Adaptation = SAO.Adaptation or {}
local Adaptation = SAO.Adaptation

local SOURCE_WEIGHT = {
    lived = 1.0,
    witnessed = 0.6,
    told = 0.4,
}

local function clamp01(value)
    value = tonumber(value) or 0.0
    if value < 0.0 then return 0.0 end
    if value > 1.0 then return 1.0 end
    return value
end

function Adaptation.stateOf(id)
    local rec = SAO.Identity and SAO.Identity.get(id) or nil
    if not rec then return nil end
    if type(rec.mutationKnowledge) ~= "table" then
        rec.mutationKnowledge = {}
    end
    return rec.mutationKnowledge
end

function Adaptation.observe(id, form, performance, source, day)
    if type(id) ~= "string" or type(form) ~= "string"
        or form == "" or form == "none" then
        return false
    end

    local state = Adaptation.stateOf(id)
    if not state then return false end

    performance = clamp01(performance)
    source = SOURCE_WEIGHT[source] and source or "witnessed"
    day = tonumber(day) or 0
    local weight = SOURCE_WEIGHT[source] * (0.5 + performance * 0.5)

    local entry = state[form]
    if not entry then
        entry = {
            form = form,
            weight = 0.0,
            firstDay = day,
            lastDay = day,
            source = source,
            performance = performance,
            performances = {},
            events = {},
        }
        state[form] = entry
    end

    entry.lastDay = day
    entry.source = source
    entry.weight = clamp01(entry.weight + weight * 0.10)
    entry.performance = clamp01(
        ((entry.performance or 0.0) + performance) / 2.0)

    entry.performances[#entry.performances + 1] = performance
    if #entry.performances > 20 then
        table.remove(entry.performances, 1)
    end

    entry.events[#entry.events + 1] = {
        day = day,
        source = source,
        performance = performance,
    }
    if #entry.events > 20 then
        table.remove(entry.events, 1)
    end

    if SAO.Lessons and entry.weight >= 0.25 then
        SAO.Lessons.learn(
            id, "measure-the-danger", entry.weight, source)
    end

    return true
end

function Adaptation.knowledgeOf(id, form)
    local state = Adaptation.stateOf(id)
    if not state or not form then return 0.0 end
    local entry = state[form]
    return entry and entry.weight or 0.0
end

function Adaptation.riskMultiplier(id, form)
    local knowledge = Adaptation.knowledgeOf(id, form)
    return math.max(0.5, 1.0 - knowledge * 0.5)
end

function Adaptation.fleeAdjustment(id, form)
    local knowledge = Adaptation.knowledgeOf(id, form)
    return math.max(0.7, 1.0 - knowledge * 0.3)
end

function Adaptation.tell(fromId, toId, day)
    if type(fromId) ~= "string" or type(toId) ~= "string"
        or fromId == toId then
        return false
    end
    if SAO.Perception and SAO.Perception.willBelieve
        and not SAO.Perception.willBelieve(toId, fromId) then
        return false
    end

    local fromState = Adaptation.stateOf(fromId)
    if not fromState then return false end

    local bestForm, bestEntry
    for form, entry in pairs(fromState) do
        if not bestEntry or entry.weight > bestEntry.weight then
            bestForm, bestEntry = form, entry
        end
    end
    if not bestForm or not bestEntry then return false end

    return Adaptation.observe(
        toId,
        bestForm,
        bestEntry.performance,
        "told",
        day)
end

function Adaptation.describe(id)
    local state = Adaptation.stateOf(id)
    if not state then return "no mutation knowledge" end

    local parts = {}
    for form, entry in pairs(state) do
        parts[#parts + 1] = string.format(
            "%s %.0f%%", form, entry.weight * 100)
    end
    if #parts == 0 then return "no mutation knowledge" end
    table.sort(parts)
    return table.concat(parts, ", ")
end

return Adaptation
