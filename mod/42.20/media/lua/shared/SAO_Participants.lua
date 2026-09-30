-- Engine slots also carry an explicitly detached study camera/loading anchor.
-- Actor-facing queries admit people; representation reads residency separately.
SAO = SAO or {}
SAO.Participants = SAO.Participants or {}
local P = SAO.Participants

function P.isObserver(body)
    return body ~= nil and body:getModData().SAO_ObserverAnchor == true
end

function P.player(index)
    local body = getSpecificPlayer(index)
    if P.isObserver(body) then return nil end
    return body
end

function P.residencyCenter()
    local reference = getSpecificPlayer(0)
    if not reference then return nil end
    return reference:getX(), reference:getY(), reference:getZ()
end

function P.residencyCenters()
    local result = {}
    -- The installed engine has four local infrastructure slots. Actor queries
    -- exclude detached observers; physical residency reads their native centers.
    for index = 0, 3 do
        local reference = getSpecificPlayer(index)
        if reference then
            result[#result + 1] = { x = reference:getX(), y = reference:getY(), z = reference:getZ() }
        end
    end
    return result
end
