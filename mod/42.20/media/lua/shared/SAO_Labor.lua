-- SAO_Labor.lua - work as pressure, capacity, material, and recognition.

SAO = SAO or {}
SAO.Labor = SAO.Labor or {}
local Labor = SAO.Labor

function Labor.capabilityOf(id)
    local capability = {}
    -- Who somebody was is the census's to say (DR-009), so this reads
    -- skills only; nothing here writes `occupation`.
    if SAO.Census then
        capability.canCook = (SAO.Census.skillOf(id, "Cooking") or -1) > 0
        capability.canForage = (SAO.Census.skillOf(id, "Foraging") or -1) > 0
        capability.canTreat = (SAO.Census.skillOf(id, "First Aid") or -1) > 0
    end
    return capability
end

function Labor.possible(id, tick, pressure)
    local work = {}
    local capability = Labor.capabilityOf(id)
    if capability.canCook then work[#work + 1] = "cook" end
    if capability.canForage then work[#work + 1] = "forage" end
    if capability.canTreat then work[#work + 1] = "treat" end
    if SAO.Standing and SAO.Standing.mayEngageZombie(id) then
        work[#work + 1] = "watch"
    end
    if pressure > 0.75 then work[#work + 1] = "urgent" end
    return work
end

function Labor.choose(id, tick, pressure)
    local possible = Labor.possible(id, tick, pressure)
    if #possible == 0 then return nil end
    local options = SandboxVars and SandboxVars.SurvivorAwareness or nil
    local materialEnabled = not options or options.Material ~= false
    if materialEnabled and SAO.Material and SAO.Material.storeForPerson then
        local store = SAO.Material.storeForPerson(id)
        -- `next` is not in this engine's Lua, so the emptiness probe
        -- is a pairs walk that stops at the first entry.
        local stocked = false
        if store and store.items then
            for _ in pairs(store.items) do
                stocked = true
                break
            end
        end
        if stocked then
            possible[#possible + 1] = "quartermaster"
        end
    end
    local best, bestScore
    for _, work in ipairs(possible) do
        local score = pressure
        if SAO.Lessons and SAO.Lessons.has(id, work) then
            score = score + 0.15
        end
        if SAO.Standing and SAO.Standing.groupOf(id) then
            score = score + 0.10
        end
        if not bestScore or score > bestScore then
            best, bestScore = work, score
        end
    end
    return best
end

function Labor.recognize(id, work)
    if not SAO.Branching then return nil end
    return SAO.Branching.recognize(id, work)
end

return Labor
