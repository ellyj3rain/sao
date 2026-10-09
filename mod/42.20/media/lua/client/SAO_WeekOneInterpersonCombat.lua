-- Bandits2's clan and global hostility fields are source provenance for two
-- admitted Week One people. Their actual conflict belongs to SAO Standing.
SAO = SAO or {}
SAO.WeekOneInterpersonCombat = SAO.WeekOneInterpersonCombat or {}
local I = SAO.WeekOneInterpersonCombat
local OWNER = "BanditsWeekOne"
local original, wrapped

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function admitted(brain)
    if type(brain) ~= "table" or brain.saoWeekOneOrigin ~= OWNER
        or not finite(brain.id) or brain.id % 1 ~= 0
        or not finite(brain.born) or not (BanditZombie
            and type(BanditZombie.GetInstanceById) == "function"
            and SAO.WeekOneContinuity
            and type(SAO.WeekOneContinuity.sourceBodyFor) == "function")
        then return nil end
    local ok, body, marker, alive = pcall(function()
        local candidate = BanditZombie.GetInstanceById(brain.id)
        return candidate, candidate and candidate:getModData(),
            candidate and candidate:isAlive()
    end)
    if not ok or not body or alive ~= true or type(marker) ~= "table"
        or marker.SAOWeekOneOrigin ~= OWNER
        or marker.SAOWeekOneBrainId ~= brain.id
        or marker.SAOWeekOneBorn ~= brain.born
        or type(marker.SAOWeekOnePersonId) ~= "string"
        or marker.SAOWeekOnePersonId == "" then return nil end
    -- This existing read verifies the durable row, current source claim,
    -- living physical body, exact brain and no competing SAO representation.
    local exact, currentBody, currentBrain = pcall(
        SAO.WeekOneContinuity.sourceBodyFor, marker.SAOWeekOnePersonId)
    if not exact or currentBody ~= body or currentBrain ~= brain then return nil end
    return marker.SAOWeekOnePersonId
end

function I.areEnemies(brain1, brain2)
    if not original then return false end
    -- A nil brain is the source's ordinary zombie case, not an NPC relation.
    if brain1 == nil or brain2 == nil then return original(brain1, brain2) end
    local firstMarked = type(brain1) == "table"
        and brain1.saoWeekOneOrigin == OWNER
    local secondMarked = type(brain2) == "table"
        and brain2.saoWeekOneOrigin == OWNER
    if not firstMarked and not secondMarked then
        return original(brain1, brain2)
    end
    local firstId = firstMarked and admitted(brain1) or nil
    local secondId = secondMarked and admitted(brain2) or nil
    if firstMarked and not firstId or secondMarked and not secondId then
        return false
    end
    -- The source utility combines both brains' global flags symmetrically.
    -- Until the foreign actor has an exact SAO identity, its result could
    -- promote this person's source flags into a conflict decision.
    if not firstMarked or not secondMarked then
        return false
    end
    if firstId == secondId then return false end
    local standing = SAO.Standing
    if not (standing and type(standing.isHostileTo) == "function"
        and type(standing.groupOf) == "function") then return false end
    local ok, firstHostile, secondHostile, firstGroup, secondGroup = pcall(
        function()
            return standing.isHostileTo(firstId, secondId),
                standing.isHostileTo(secondId, firstId),
                standing.groupOf(firstId), standing.groupOf(secondId)
        end)
    if not ok or firstGroup ~= nil and firstGroup == secondGroup then
        return false
    end
    return firstHostile == true or secondHostile == true
end

function I.ready()
    return wrapped ~= nil and BanditUtils
        and BanditUtils.AreEnemies == wrapped
end

function I.install()
    if I.ready() then return true end
    if wrapped then return false end
    if not (BanditUtils and type(BanditUtils.AreEnemies) == "function") then
        return false
    end
    original = BanditUtils.AreEnemies
    wrapped = function(brain1, brain2)
        return I.areEnemies(brain1, brain2)
    end
    BanditUtils.AreEnemies = wrapped
    return true
end
