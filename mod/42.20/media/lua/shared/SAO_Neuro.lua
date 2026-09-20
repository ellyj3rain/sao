-- SAO_Neuro - event-derived brain health and its behavioural projections.
-- ---------------------------------------------------------------------------
-- The graph is a history, not a current scalar dressed as one.  Every change
-- in wound infection, current toxic burden, withdrawal, pathogen course,
-- terminal state, or physical clearance is first timestamped.  The interval
-- before that timestamp is integrated from the facts that were active during
-- it.  Therefore a late observation cannot charge its new cause backward.
--
-- ZAO owns this durable history when installed because it owns pathogen and
-- terminal state.  Standalone SAO stores the same schema on the survivor
-- record.  SAO owns body observations and the cognitive, memory, motor, and
-- affective projections used by survivor behaviour.

SAO = SAO or {}
SAO.Neuro = SAO.Neuro or {}
local Neuro = SAO.Neuro

Neuro.AFFLICTED_FLOOR = 0.30
Neuro.CROSSED_FLOOR = 0.90

Neuro.KNOX_PEAK_RATE = 0.08
Neuro.SEPSIS_RATE = 0.02
Neuro.DRUG_TOXIN_RATE = 0.05
Neuro.WITHDRAWAL_RATE = 0.02
Neuro.BASE_CLEARANCE_RATE = 0.04
Neuro.HISTORY_LIMIT = 512

local EPSILON = 0.0000001

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function copyActive(active)
    active = active or {}
    return {
        wound = active.wound == true,
        toxin = tonumber(active.toxin) or 0.0,
        withdrawal = active.withdrawal == true,
        terminal = active.terminal,
        knoxStart = tonumber(active.knoxStart),
        knoxEnd = tonumber(active.knoxEnd),
        clearance = tonumber(active.clearance) or 1.0,
    }
end

function Neuro.isActive()
    local sv = SandboxVars and SandboxVars.SurvivorAwareness
    if sv and sv.Neuroinflammation ~= nil then
        return sv.Neuroinflammation == true
    end
    return true
end

local function countyHours()
    local hours = 0.0
    pcall(function()
        if SAO.History and SAO.History.countyHours then
            hours = SAO.History.countyHours()
        end
    end)
    return tonumber(hours) or 0.0
end

-- Terminal state is read from its actual owner.  `rec.terminalState` was never
-- a written SAO field and must not become a shadow pathogen store.
local function terminalOf(rec)
    local terminal = nil
    if rec and rec.id and ZAO and ZAO.StateStore then
        pcall(function()
            local state = ZAO.StateStore.read(tostring(rec.id))
            terminal = state and state.terminalState or nil
        end)
    end
    if terminal == "crossed" or terminal == "afflicted" then return terminal end
    if rec and rec.afflictedReturn then return "afflicted" end
    return nil
end

local function floorOf(active)
    local terminal = active and active.terminal or nil
    if terminal == "crossed" then return Neuro.CROSSED_FLOOR end
    if terminal == "afflicted" then return Neuro.AFFLICTED_FLOOR end
    return 0.0
end

local function loadFrom(burden, active)
    local floor = floorOf(active)
    local fraction = 1.0 - math.exp(-math.max(0.0, tonumber(burden) or 0.0))
    return clamp(floor + (1.0 - floor) * fraction, floor, 1.0)
end

local function burdenFrom(load, active)
    local floor = floorOf(active)
    load = clamp(load, floor, 1.0)
    if load <= floor + EPSILON then return 0.0 end
    local fraction = clamp((load - floor) / math.max(EPSILON, 1.0 - floor),
        0.0, 0.999999)
    return -math.log(1.0 - fraction)
end

local function ownerState(rec, create)
    if not rec then return nil end
    if ZAO and ZAO.Brain and ZAO.Brain.stateFor and rec.id ~= nil then
        local state = nil
        pcall(function()
            state = ZAO.Brain.stateFor(tostring(rec.id), create == true)
        end)
        return state
    end
    if not rec.brainHealth and create then
        rec.brainHealth = { version = 2, history = {} }
    end
    return rec.brainHealth
end

local function withdrawalOf(rec, override)
    if override and override.withdrawal ~= nil then
        return override.withdrawal == true
    end
    local phase = 0
    if rec and rec.id and SAO.Habits and SAO.Habits.withdrawalPhase then
        pcall(function() phase = SAO.Habits.withdrawalPhase(rec.id) or 0 end)
    end
    return tonumber(phase) and tonumber(phase) >= 3 or false
end

local function knoxWindow(rec, override)
    if override and override.knoxStart ~= nil then
        return tonumber(override.knoxStart), tonumber(override.knoxEnd)
    end
    if not rec or not rec.knoxInfected then return nil, nil end
    local startAt = tonumber(rec.infectionStartedAtHours)
    local endAt = tonumber(rec.biteDeathAtHours)
    local span = tonumber(rec.infectionSpanHours)
    if not startAt and endAt and span then startAt = endAt - span end
    if not endAt and startAt and span then endAt = startAt + span end
    if not startAt or not endAt or endAt <= startAt then return nil, nil end
    return startAt, endAt
end

local function clearanceOf(rec, atHours, override)
    if override and override.clearance ~= nil then
        return clamp(override.clearance, 0.0, 1.0)
    end

    local hunger = override and tonumber(override.hunger) or nil
    local thirst = override and tonumber(override.thirst) or nil
    local fatigue = override and tonumber(override.fatigue) or nil
    if hunger == nil and rec and rec.id and SAO.Body and SAO.Needs then
        pcall(function()
            local body = SAO.Body.get(rec.id)
            local needs = body and SAO.Needs.read(body) or nil
            if needs then
                hunger = tonumber(needs.hunger)
                thirst = tonumber(needs.thirst)
                fatigue = tonumber(needs.fatigue)
            end
        end)
    end

    local impaired = 0
    if hunger ~= nil then
        if hunger >= 0.50 then impaired = impaired + 1 end
    elseif rec and tonumber(rec.lastFoodDay) then
        if atHours / 24.0 - tonumber(rec.lastFoodDay) >= 2.0 then
            impaired = impaired + 1
        end
    end
    if thirst ~= nil then
        if thirst >= 0.40 then impaired = impaired + 1 end
    elseif rec and tonumber(rec.lastWaterDay) then
        if atHours / 24.0 - tonumber(rec.lastWaterDay) >= 1.0 then
            impaired = impaired + 1
        end
    end
    if fatigue ~= nil and fatigue >= 0.75 then impaired = impaired + 1 end
    if impaired == 0 then return 1.0 end
    if impaired == 1 then return 0.60 end
    if impaired == 2 then return 0.30 end
    return 0.15
end

local function factsOf(rec, atHours, override)
    override = override or {}
    local toxin = override.toxin
    if toxin == nil then
        toxin = clamp((tonumber(rec and rec.currentToxicBurden) or 0.0) / 100.0,
            0.0, 1.0)
    else
        toxin = clamp(toxin, 0.0, 1.0)
    end
    local startAt, endAt = knoxWindow(rec, override)
    local wound = override.wound
    if wound == nil then wound = rec and rec.woundInfected == true end
    local terminal = override.terminal
    if terminal == nil then terminal = terminalOf(rec) end
    return {
        wound = wound == true,
        toxin = toxin,
        withdrawal = withdrawalOf(rec, override),
        terminal = terminal,
        knoxStart = startAt,
        knoxEnd = endAt,
        clearance = clearanceOf(rec, atHours, override),
    }
end

local function sameNumber(a, b)
    if a == nil or b == nil then return a == b end
    return math.abs(a - b) <= EPSILON
end

local function sameActive(a, b)
    if not a or not b then return false end
    return a.wound == b.wound
        and sameNumber(a.toxin, b.toxin)
        and a.withdrawal == b.withdrawal
        and a.terminal == b.terminal
        and sameNumber(a.knoxStart, b.knoxStart)
        and sameNumber(a.knoxEnd, b.knoxEnd)
        and sameNumber(a.clearance, b.clearance)
end

local function constantRate(active)
    local rate = 0.0
    if active.wound then rate = rate + Neuro.SEPSIS_RATE end
    rate = rate + clamp(active.toxin, 0.0, 1.0) * Neuro.DRUG_TOXIN_RATE
    if active.withdrawal then rate = rate + Neuro.WITHDRAWAL_RATE end
    return rate
end

local function constantContribution(rate, decayRate, elapsed)
    if elapsed <= 0.0 or rate <= 0.0 then return 0.0 end
    if decayRate <= EPSILON then return rate * elapsed end
    return rate * (1.0 - math.exp(-decayRate * elapsed)) / decayRate
end

-- Exact convolution of the Knox sine forcing with exponential clearance.
-- Clipping the integral to the infection window lets an interval cross onset
-- or terminal time without endpoint sampling or timestep dependence.
local function knoxContribution(active, fromHours, toHours, decayRate)
    local startAt = tonumber(active.knoxStart)
    local endAt = tonumber(active.knoxEnd)
    if not startAt or not endAt or endAt <= startAt then return 0.0 end
    local left = math.max(fromHours, startAt)
    local right = math.min(toHours, endAt)
    if right <= left then return 0.0 end
    local span = endAt - startAt
    local omega = math.pi / span
    local denom = decayRate * decayRate + omega * omega
    local function primitive(offset)
        return math.exp(decayRate * offset)
            * (decayRate * math.sin(omega * offset)
                - omega * math.cos(omega * offset)) / denom
    end
    local weighted = math.exp(-decayRate * (toHours - startAt))
        * (primitive(right - startAt) - primitive(left - startAt))
    return Neuro.KNOX_PEAK_RATE * weighted
end

local function integrate(burden, active, fromHours, toHours, enabled)
    burden = math.max(0.0, tonumber(burden) or 0.0)
    fromHours = tonumber(fromHours) or 0.0
    toHours = tonumber(toHours) or fromHours
    if toHours <= fromHours or enabled == false then return burden end
    active = copyActive(active)
    local elapsed = toHours - fromHours
    local decayRate = Neuro.BASE_CLEARANCE_RATE
        * clamp(active.clearance, 0.0, 1.0)
    local decayed = burden * math.exp(-decayRate * elapsed)
    local driven = constantContribution(constantRate(active), decayRate, elapsed)
        + knoxContribution(active, fromHours, toHours, decayRate)
    return math.max(0.0, decayed + driven)
end

-- Deterministic test/inspection surface: no durable state is touched.
function Neuro.project(burden, active, fromHours, toHours, enabled)
    local projected = integrate(burden, active, fromHours, toHours, enabled)
    return projected, loadFrom(projected, active)
end

local function appendHistory(state, atHours, source)
    state.history = state.history or {}
    state.history[#state.history + 1] = {
        atHours = atHours,
        source = source or "observation",
        burden = state.burden or 0.0,
        load = loadFrom(state.burden, state.active),
        active = copyActive(state.active),
        enabled = state.enabled ~= false,
    }
    while #state.history > Neuro.HISTORY_LIMIT do
        table.remove(state.history, 1)
    end
end

local function ensureState(rec, atHours)
    local state = ownerState(rec, true)
    if not state then return nil end
    state.version = 2
    state.history = state.history or {}
    if tonumber(state.atHours) == nil then
        state.atHours = atHours
        state.active = factsOf(rec, atHours, nil)
        state.enabled = Neuro.isActive()
        state.burden = burdenFrom(tonumber(rec.neuroinflammation) or 0.0,
            state.active)
        rec.neuroinflammation = nil
        appendHistory(state, atHours, "initial-observation")
    else
        state.atHours = tonumber(state.atHours)
        state.burden = math.max(0.0, tonumber(state.burden) or 0.0)
        state.active = copyActive(state.active)
        if state.enabled == nil then state.enabled = true end
    end
    return state
end

-- Advance through the facts that were active, then stamp newly observed facts
-- at their observation time.  `override` values describe the state beginning
-- at that instant; they never apply to the interval that just ended.
function Neuro.observe(rec, atHours, source, override)
    if not rec then return 0.0 end
    atHours = tonumber(atHours) or countyHours()
    local state = ensureState(rec, atHours)
    if not state then return 0.0 end
    if atHours < state.atHours then
        return Neuro.isActive() and loadFrom(state.burden, state.active) or 0.0
    end

    local priorAt = state.atHours
    local priorLoad = loadFrom(state.burden, state.active)
    state.burden = integrate(state.burden, state.active, state.atHours, atHours,
        state.enabled)
    state.atHours = atHours

    local enabled = Neuro.isActive()
    local toggleChanged = enabled ~= state.enabled
    state.enabled = enabled
    local observed = factsOf(rec, atHours, override)
    local factsChanged = not sameActive(state.active, observed)
    if factsChanged then state.active = observed end

    local history = state.history or {}
    local last = history[#history]
    local checkpointDue = not last or atHours - (tonumber(last.atHours) or atHours) >= 1.0
    local loadChanged = math.abs(loadFrom(state.burden, state.active) - priorLoad) >= 0.01
    if toggleChanged or factsChanged or checkpointDue
        or (atHours > priorAt and loadChanged) then
        appendHistory(state, atHours, source or (factsChanged and "changed" or "elapsed"))
    end
    if not enabled then return 0.0 end
    return loadFrom(state.burden, state.active)
end

function Neuro.observeBody(rec, body, atHours, source)
    local override = {}
    if body and SAO.Needs then
        pcall(function()
            local needs = SAO.Needs.read(body)
            if needs then
                override.hunger = needs.hunger
                override.thirst = needs.thirst
                override.fatigue = needs.fatigue
            end
        end)
    end
    return Neuro.observe(rec, atHours, source or "body-observation", override)
end

-- `deltaHours` remains accepted for existing callers, but accounting follows
-- the durable cursor.  Repeating the same timestamp cannot double-charge it.
function Neuro.advance(rec, deltaHours, nowHours)
    return Neuro.observe(rec, nowHours, "elapsed", nil)
end

function Neuro.recordTerminal(rec, terminal, atHours, source)
    return Neuro.observe(rec, atHours, source or "terminal-state",
        { terminal = terminal })
end

function Neuro.stateOf(rec)
    return ownerState(rec, false)
end

function Neuro.loadOf(rec)
    if not rec or not Neuro.isActive() then return 0.0 end
    local state = ownerState(rec, false)
    if state and tonumber(state.atHours) ~= nil then
        return loadFrom(state.burden, state.active)
    end
    local terminal = terminalOf(rec)
    local active = { terminal = terminal }
    local legacy = tonumber(rec.neuroinflammation)
    if legacy then return clamp(legacy, floorOf(active), 1.0) end
    return floorOf(active)
end

function Neuro.loadOfId(id)
    if id == nil then return 0.0 end
    local rec = nil
    pcall(function() rec = SAO.Identity and SAO.Identity.get(id) end)
    return Neuro.loadOf(rec)
end

function Neuro.clarityOf(rec)
    if not rec or not Neuro.isActive() then return 1.0 end
    return clamp(1.0 - Neuro.loadOf(rec), 0.0, 1.0)
end

function Neuro.clarityOfId(id)
    if id == nil or not Neuro.isActive() then return 1.0 end
    local rec = nil
    pcall(function() rec = SAO.Identity and SAO.Identity.get(id) end)
    return Neuro.clarityOf(rec)
end

function Neuro.affectiveVolatility(rec)
    if not rec or not Neuro.isActive() then return 0.0 end
    return Neuro.loadOf(rec) * 0.85
end

function Neuro.motorSteadiness(rec)
    if not rec or not Neuro.isActive() then return 1.0 end
    return clamp(1.0 - Neuro.loadOf(rec) * 0.70, 0.0, 1.0)
end

function Neuro.decisionInterval(id, base)
    base = math.max(1, tonumber(base) or 1)
    local load = Neuro.loadOfId(id)
    return math.max(1, math.floor(base * (1.0 + load * 0.75) + 0.5))
end

function Neuro.causesOf(rec)
    local state = ownerState(rec, false)
    local active = state and state.active or factsOf(rec, countyHours(), nil)
    local causes = {}
    if active.knoxStart and active.knoxEnd then causes[#causes + 1] = "pathogen" end
    if active.wound then causes[#causes + 1] = "sepsis" end
    if (active.toxin or 0) > 0 then causes[#causes + 1] = "toxin" end
    if active.withdrawal then causes[#causes + 1] = "withdrawal" end
    if active.terminal then causes[#causes + 1] = active.terminal end
    return causes
end

-- Return the recorded curve within a window.  The last point before the
-- window is retained as the line's origin, then actual observations follow.
function Neuro.series(rec, nowHours, windowHours, maxPoints)
    local state = ownerState(rec, false)
    if not state or type(state.history) ~= "table" then return {} end
    nowHours = tonumber(nowHours) or countyHours()
    windowHours = math.max(0.0, tonumber(windowHours) or 168.0)
    maxPoints = math.max(2, math.floor(tonumber(maxPoints) or 64))
    local startAt = nowHours - windowHours
    local selected = {}
    local before = nil
    for _, event in ipairs(state.history) do
        local at = tonumber(event.atHours)
        if at and at < startAt then
            before = event
        elseif at and at <= nowHours then
            selected[#selected + 1] = { atHours = at,
                load = tonumber(event.load) or 0.0, source = event.source }
        end
    end
    if before then
        table.insert(selected, 1, { atHours = tonumber(before.atHours),
            load = tonumber(before.load) or 0.0, source = before.source })
    end
    if #selected == 0 and tonumber(state.atHours) then
        selected[1] = { atHours = state.atHours,
            load = loadFrom(state.burden, state.active), source = "current" }
    elseif tonumber(state.atHours) and state.atHours <= nowHours then
        local last = selected[#selected]
        if not last or math.abs(last.atHours - state.atHours) > EPSILON then
            selected[#selected + 1] = { atHours = state.atHours,
                load = loadFrom(state.burden, state.active), source = "current" }
        end
    end
    if #selected <= maxPoints then return selected end
    local thinned = {}
    for index = 1, maxPoints do
        local pick = math.floor((index - 1) * (#selected - 1)
            / (maxPoints - 1) + 1.5)
        if pick > #selected then pick = #selected end
        thinned[#thinned + 1] = selected[pick]
    end
    return thinned
end

return Neuro
