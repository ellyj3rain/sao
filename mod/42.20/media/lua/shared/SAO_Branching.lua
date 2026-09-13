-- SAO_Branching.lua - the county's one branching graph.

SAO = SAO or {}
SAO.Branching = SAO.Branching or {}
local Branching = SAO.Branching

Branching.surfaces = Branching.surfaces or {}
Branching.pressures = Branching.pressures or {}
Branching.branches = Branching.branches or {}
Branching.patterns = Branching.patterns or {}
Branching.offices = Branching.offices or {}

function Branching.registerSurface(name, reader)
    if type(name) ~= "string" or type(reader) ~= "function" then return false end
    Branching.surfaces[name] = reader
    return true
end

function Branching.registerPressure(name, reader)
    if type(name) ~= "string" or type(reader) ~= "function" then return false end
    Branching.pressures[name] = reader
    return true
end

function Branching.registerBranch(branch)
    if type(branch) ~= "table" or type(branch.id) ~= "string"
        or type(branch.weight) ~= "function" then
        return false
    end
    Branching.branches[branch.id] = branch
    return true
end

function Branching.pressureFor(id, tick)
    local total = 0.0
    for name, reader in pairs(Branching.pressures) do
        local ok, value = pcall(reader, id, tick)
        if ok and type(value) == "number" and value > 0 then
            total = total + value
        end
    end
    return math.min(1.0, total)
end

function Branching.select(id, tick)
    local best, bestScore
    local pressure = Branching.pressureFor(id, tick)
    for _, branch in pairs(Branching.branches) do
        local ok, score = pcall(branch.weight, id, tick, pressure)
        if ok and type(score) == "number"
            and (not bestScore or score > bestScore) then
            best, bestScore = branch, score
        end
    end
    if best then
        Branching.record(id, best.id, tick)
        return best
    end
    return nil
end

function Branching.record(id, branchId, tick)
    local key = tostring(id) .. ":" .. tostring(branchId)
    local pattern = Branching.patterns[key]
    if not pattern then
        pattern = { id = id, branch = branchId, count = 0, firstAt = tick,
                    lastAt = tick }
        Branching.patterns[key] = pattern
    end
    pattern.count = pattern.count + 1
    pattern.lastAt = tick
    return pattern
end

function Branching.recognize(id, branchId)
    local key = tostring(id) .. ":" .. tostring(branchId)
    local pattern = Branching.patterns[key]
    if pattern and pattern.count >= 3 then
        return pattern
    end
    return nil
end

function Branching.formOffice(id, branchId, jurisdiction)
    local pattern = Branching.recognize(id, branchId)
    if not pattern then return nil end
    local office = {
        person = id,
        branch = branchId,
        jurisdiction = jurisdiction or branchId,
        sincePattern = pattern,
    }
    Branching.offices[tostring(id) .. ":" .. tostring(branchId)] = office
    return office
end

return Branching
