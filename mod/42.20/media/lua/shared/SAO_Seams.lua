-- SAO_Seams.lua - which parts of this mod are still running ([B33]).
--
-- Every subsystem sits behind a fault counter ([A21]): three faults
-- and the seam disables ITSELF, so one broken thing cannot take the
-- county with it. That is the right shape and it has exactly one
-- cost - a seam that goes dark leaves a world that looks entirely
-- normal and quietly is not. Survivors stop appearing, or stop
-- moving, and nothing anywhere says why.
--
-- Until now the only report was print() to the console, which in
-- normal play nobody is reading. [B33] found the same class in
-- combat: the readiness question was already built and nothing ever
-- asked it. This is the register that makes the answer askable.
-- Seams say when they go dark; the Ledger - the panel the player
-- already opens - carries it in its own top line, and no new surface
-- is invented to hold it.
--
-- ONLY permanent failures belong here. Three of the five bulkheads
-- recover on their own: the controller resets its count and drops
-- everyone, a faulting agent is dropped and its count cleared, a
-- locomotion job dies and the next one starts fresh. A register that
-- filled up with things that had already fixed themselves would be
-- noise, and noise is how a real warning gets ignored.

SAO = SAO or {}
SAO.Seams = SAO.Seams or {}
local Seams = SAO.Seams

Seams.dark = Seams.dark or {}

-- The first report wins. A seam disables itself once; anything after
-- that is the same failure being noticed again, and overwriting the
-- reason would replace the cause with a symptom.
function Seams.wentDark(name, why)
    if not name then return end
    name = tostring(name)
    if Seams.dark[name] then return end
    Seams.dark[name] = tostring(why or "repeated faults")
end

function Seams.isDark(name)
    return name ~= nil and Seams.dark[tostring(name)] ~= nil
end

function Seams.why(name)
    if name == nil then return nil end
    return Seams.dark[tostring(name)]
end

-- Sorted, so the line the player reads does not reshuffle itself
-- between renders.
function Seams.names()
    local out = {}
    for name in pairs(Seams.dark) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function Seams.count()
    local n = 0
    for _ in pairs(Seams.dark) do n = n + 1 end
    return n
end
