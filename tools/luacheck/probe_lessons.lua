-- Border 62's recorder. Loaded into a Kahlua VM AFTER the real
-- modules, so `H.generate` runs its own code and only the endpoint is
-- replaced: `SAO.Lessons.learn` writes the key into a list instead of
-- into a survivor.
--
-- Nothing here models the draw. The traits come from the real
-- SAO_Disposition, the occupation class from the real SAO_Census, the
-- grammar and the pool and the index from the real SAO_History, and
-- the hash from the real SAO_Hash. That is the whole point: [B48]
-- cleared four hypotheses by reimplementing this loop in Python and
-- was wrong about the machine, not the code.

SAO = SAO or {}

SAO.Lessons = SAO.Lessons or {}
SAO.Lessons.REGISTRY = SAO.Lessons.REGISTRY or {}
DRAWN = {}
function SAO.Lessons.learn(id, key, weight, src, of)
    DRAWN[#DRAWN + 1] = tostring(key)
    return true
end

-- `trait()` reads a record's echoes through Identity when one exists.
-- A fresh county has none, so nil is the honest answer here - and it
-- keeps this probe from inventing a personality the mod would not.
SAO.Identity = SAO.Identity or {}
function SAO.Identity.get(id) return nil end

-- Run the real generator over a county of `count` people and hand back
-- every key it asked to have learned.
function PROBE_DRAW(count)
    for i = 1, count do
        local id = "sao-" .. i
        pcall(function()
            SAO.History.generate(id, { id = id, x = 0, y = 0, z = 0 })
        end)
    end
    return table.concat(DRAWN, ",")
end
