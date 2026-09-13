-- SAO_Pressure.lua - pressure from the state the person actually holds.

SAO = SAO or {}
SAO.Pressure = SAO.Pressure or {}
local Pressure = SAO.Pressure

function Pressure.threat(id, tick, x, y)
    if not SAO.Perception then return 0 end
    local threat = SAO.Perception.nearestBelievedZombie(id, tick, x, y)
    if not threat then return 0 end
    local distance = math.max(1.0, tonumber(threat.dist) or 20.0)
    local closeness = 20.0 / distance
    local formPressure = tonumber(threat.formPerformance) or 0
    return math.min(1.0, closeness * (0.6 + formPressure * 0.4))
end

function Pressure.needs(id)
    if not SAO.Needs then return 0 end
    local body = SAO.Body and SAO.Body.get(id) or nil
    local needs = body and SAO.Needs.read(body) or nil
    if not needs then return 0 end
    local hunger = tonumber(needs.hunger) or 0
    local thirst = tonumber(needs.thirst) or 0
    local fatigue = tonumber(needs.fatigue) or 0
    return math.min(1.0, hunger * 0.35 + thirst * 0.45 + fatigue * 0.20)
end

function Pressure.injury(id)
    if not SAO.Medical then return 0 end
    local body = SAO.Body and SAO.Body.get(id) or nil
    local bleeding = body and SAO.Needs and SAO.Needs.bleeding(body) or 0
    return math.min(1.0, bleeding * 0.25)
end

function Pressure.infection(id)
    if not SAO.Course then return 0 end
    local rec = SAO.Identity and SAO.Identity.get(id) or nil
    if not rec then return 0 end
    local progress = tonumber(rec.immuneProgress) or 0
    return math.min(1.0, progress)
end

function Pressure.weather()
    if not SandboxVars then return 0 end
    local rain = tonumber(SandboxVars.Rain) or 0
    local temperature = tonumber(SandboxVars.Temperature) or 0
    return math.min(1.0, rain * 0.5 + math.max(0, 1.0 - temperature) * 0.5)
end

function Pressure.total(id, tick, x, y)
    local values = {
        Pressure.threat(id, tick, x, y),
        Pressure.needs(id),
        Pressure.injury(id),
        Pressure.infection(id),
        Pressure.weather(),
    }
    local total = 0
    for _, value in ipairs(values) do total = total + value end
    return math.min(1.0, total)
end

return Pressure
