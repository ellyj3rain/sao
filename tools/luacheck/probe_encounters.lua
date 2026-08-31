-- [B51] What a pass of the dormant-encounter sweep costs, measured on
-- the engine rather than reasoned about.
--
-- `dormantEncounters` in SAO_Population.lua is a NESTED `pairs` over
-- `SAO.Identity.all()`. The outer loop is budgeted - ENCOUNTER_BUDGET
-- is 12 records a pass, resuming where the last stopped. The INNER
-- loop is not budgeted: it walks every record in the store, every
-- pass, and rejects the ones it cannot use inside the body.
--
-- `Identity.all()` returns the whole store, and the store keeps the
-- dead on purpose - "death is durable: the record stays (a person
-- existed and died there)". The store is ModData, so the dead
-- accumulate ACROSS SESSIONS for the life of a save.
--
-- So the sweep's cost is 12 x (living + dead), and only the first term
-- is capped. This reproduces the loop's exact shape and rejection
-- order - `idB > idA`, then `recB.dead`, then the body lookup - so the
-- number is about this code rather than about loops in general.

-- A global, because LuaRun loads chunks into the environment and
-- a chunk's return value is not bound to anything.
P = {}

-- A store of `n` records, `deadFrac` of them dead. Ids are the same
-- shape the real ones are (a string), because the inner test compares
-- them with `>` and string comparison is not free.
function P.store(n, deadFrac)
    local records = {}
    local dead = math.floor(n * deadFrac)
    for i = 1, n do
        local id = "sao_" .. tostring(100000 + i)
        records[id] = {
            id = id,
            dead = i <= dead,
            x = (i * 37) % 1200,
            y = (i * 53) % 1200,
        }
    end
    return records
end

-- One pass of the sweep, with the real budget and the real rejection
-- order. `bodyOf` stands in for SAO.Body.get - a table lookup, which
-- is what it is.
function P.pass(records, budget, bodyOf, cursor)
    local met = 0
    local resumed = cursor == nil
    local outer = budget
    local last = nil
    for idA, recA in pairs(records) do
        if not resumed then
            if idA == cursor then resumed = true end
        elseif outer <= 0 then
            break
        elseif not recA.dead and not bodyOf[idA] then
            outer = outer - 1
            last = idA
            for idB, recB in pairs(records) do
                if idB > idA and not recB.dead and not bodyOf[idB] then
                    local dx, dy = recA.x - recB.x, recA.y - recB.y
                    if dx * dx + dy * dy <= 9 then
                        met = met + 1
                    end
                end
            end
        end
    end
    return met, last
end

-- `passes` passes over a store of `n`, `deadFrac` dead. Returns the
-- meetings found, so nothing here can be optimised away.
function P.run(n, deadFrac, passes)
    local records = P.store(n, deadFrac)
    local bodies = {}
    local total, cursor = 0, nil
    for _ = 1, passes do
        local met, last = P.pass(records, 12, bodies, cursor)
        total = total + met
        cursor = last
    end
    return total
end

-- The shape that SHIPPED: the living list is built once per pass and
-- the inner loop walks it, while the outer loop keeps its `pairs`
-- walk and its cursor rotation exactly as they were. Written to match
-- the code rather than to flatter it - an i/j loop over the living
-- would measure faster and would not be what runs.
function P.runShipped(n, deadFrac, passes)
    local records = P.store(n, deadFrac)
    local bodies = {}
    local total, cursor = 0, nil
    for _ = 1, passes do
        local livingId, livingRec, livingN = {}, {}, 0
        for id, rec in pairs(records) do
            if not rec.dead and not bodies[id] then
                livingN = livingN + 1
                livingId[livingN] = id
                livingRec[livingN] = rec
            end
        end
        local resumed = cursor == nil
        local outer = 12
        local last = nil
        for idA, recA in pairs(records) do
            if not resumed then
                if idA == cursor then resumed = true end
            elseif outer <= 0 then
                break
            elseif not recA.dead and not bodies[idA] then
                outer = outer - 1
                last = idA
                for li = 1, livingN do
                    local idB, recB = livingId[li], livingRec[li]
                    if idB > idA then
                        local dx, dy = recA.x - recB.x, recA.y - recB.y
                        if dx * dx + dy * dy <= 9 then
                            total = total + 1
                        end
                    end
                end
            end
        end
        cursor = last
    end
    return total
end

-- [B51] `driftStandings` walks the whole persisted relations table -
-- every survivor's row, every entry in it - once per game day. The
-- rows of the dead are never removed, so the walk is over everybody
-- who ever lived. This is the real shape of that loop, including the
-- five-term condition, because the condition is most of the cost.
function P.drift(rows, per, passes)
    local relations = {}
    for i = 1, rows do
        local mine = {}
        for j = 1, per do
            mine["sao_" .. tostring(100000 + j)] = {
                trust = (i * j % 200) / 100 - 1.0,
                atHours = (i + j) % 900,
                hostile = (i + j) % 7 == 0,
                bonded = (i + j) % 97 == 0,
            }
        end
        relations["sao_" .. tostring(100000 + i)] = mine
    end
    local moved = 0
    for _ = 1, passes do
        local nowH = 1000
        for _, rels in pairs(relations) do
            for _, r in pairs(rels) do
                if r.bonded ~= true and r.atHours
                    and nowH - r.atHours > 336
                    and r.trust and math.abs(r.trust) > 0.01 then
                    r.trust = r.trust * 0.92
                    moved = moved + 1
                    if r.hostile == true and math.abs(r.trust) < 0.2 then
                        r.hostile = false
                    end
                end
            end
        end
    end
    return moved
end

-- The shape that SHIPPED: the day's drift spread across passes with a
-- persisted cursor. Reports the WORST single pass, not the average -
-- an average would hide the one frame that stalls, which is the whole
-- thing being measured.
function P.driftShipped(rows, per, budget)
    local relations = {}
    for i = 1, rows do
        local mine = {}
        for j = 1, per do
            mine["sao_" .. tostring(100000 + j)] = {
                trust = (i * j % 200) / 100 - 1.0,
                atHours = (i + j) % 900,
                hostile = (i + j) % 7 == 0,
                bonded = (i + j) % 97 == 0,
            }
        end
        relations["sao_" .. tostring(100000 + i)] = mine
    end
    local cursor, passes, moved = nil, 0, 0
    repeat
        local walked, resumed, last = 0, cursor == nil, nil
        local nowH = 1000
        for id, rels in pairs(relations) do
            if not resumed then
                if id == cursor then resumed = true end
            elseif walked >= budget then
                break
            else
                walked = walked + 1
                last = id
                for _, r in pairs(rels) do
                    if r.bonded ~= true and r.atHours
                        and nowH - r.atHours > 336
                        and r.trust and math.abs(r.trust) > 0.01 then
                        r.trust = r.trust * 0.92
                        moved = moved + 1
                        if r.hostile == true and math.abs(r.trust) < 0.2 then
                            r.hostile = false
                        end
                    end
                end
            end
        end
        passes = passes + 1
        cursor = (last ~= nil and walked >= budget) and last or nil
    until cursor == nil
    return passes
end

-- [B51] What ONE linear walk over the identity store costs. Six of
-- these run per population pass - dormantLife, dormantAttrition twice,
-- dormantEncounters twice, materializeBand - and only the encounter
-- pair is budgeted. The body is the one those walks share: reject the
-- dead, reject anyone with a body, then a distance test.
function P.linear(n, deadFrac, passes)
    local records = P.store(n, deadFrac)
    local bodies = {}
    local seen = 0
    for _ = 1, passes do
        for id, rec in pairs(records) do
            if not rec.dead and not bodies[id] then
                local dx, dy = rec.x - 600, rec.y - 600
                if dx * dx + dy * dy <= 40000 then
                    seen = seen + 1
                end
            end
        end
    end
    return seen
end
