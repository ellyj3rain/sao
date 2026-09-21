-- SAO_Communication.lua - claims that pass between people.

SAO = SAO or {}
SAO.Communication = SAO.Communication or {}
local Communication = SAO.Communication

Communication.messages = Communication.messages or {}

local function bodyFor(id)
    local body = SAO.Body and SAO.Body.get and SAO.Body.get(id)
    if body then return body end
    local ok, player = pcall(function() return getSpecificPlayer(0) end)
    if ok and player and SAO.Standing and SAO.Standing.playerKey
        and SAO.Standing.playerKey(player) == id then return player end
    return nil
end

local function dormantHearing(rec, listener)
    if rec.dormantSleeping == true then return nil, "asleep" end
    if rec.dormantSleeping ~= false then return nil, "sleep-unobserved" end
    if rec.hibernation == nil then
        if rec.speechAccessOrigin == "generated-empty-traits" then return 1 end
        return nil, "hearing-unobserved"
    end
    local ok, access = pcall(function()
        return SAOJavaBridge:hibernationHearingAccess(rec.hibernation)
    end)
    if not ok or type(access) ~= "string" then return nil, "hearing-unavailable" end
    if access == "REFUSED:deaf" then
        if listener then return nil, "deaf" end
        return 1 -- Hearing is not required to speak.
    end
    local amount = tonumber(string.match(access, "^AVAILABLE:([%d%.eE%+%-]+)$"))
    if not amount or amount ~= amount or amount <= 0 or amount == math.huge then
        return nil, "hearing-unavailable"
    end
    return amount
end

-- A transport must establish its listeners before private testimony travels.
-- Loaded speech uses native hearing; dormant speech belongs to a real adjacent
-- encounter in the existing bodyless simulation, with no loaded participant.
function Communication.canConverse(fromId, toId, channel)
    if type(fromId) ~= "string" or type(toId) ~= "string"
        or fromId == toId then return false end
    for _, id in ipairs({ fromId, toId }) do
        local agent = SAO.Controller and SAO.Controller.agents
            and SAO.Controller.agents[id]
        if agent and agent.sleeping then return false end
    end
    if channel == "dormant-encounter" then
        if not (SAO.Identity and SAO.Identity.get and SAO.Body
            and SAO.Body.hasRepresentation) then return false end
        local a, b = SAO.Identity.get(fromId), SAO.Identity.get(toId)
        if not a or not b or a.dead or b.dead
            or SAO.Body.hasRepresentation(fromId)
            or SAO.Body.hasRepresentation(toId)
            or a.sleeping or b.sleeping then return false end
        local speaker, speakerWhy = dormantHearing(a, false)
        if not speaker then return false, speakerWhy end
        local hearing, hearingWhy = dormantHearing(b, true)
        if not hearing then return false, hearingWhy end
        local ax, ay, az = tonumber(a.x), tonumber(a.y), tonumber(a.z)
        local bx, by, bz = tonumber(b.x), tonumber(b.y), tonumber(b.z)
        if not ax or not ay or not az or not bx or not by or not bz
            or az ~= bz then return false end
        local dx, dy = ax - bx, ay - by
        local ok, weather = pcall(function() return SAOJavaBridge:speechWeatherHearing() end)
        if not ok or type(weather) ~= "number" or weather ~= weather
            or weather <= 0 or weather > 1 then return false, "weather-unavailable" end
        local reach = math.min(3, (SAO.Perception and SAO.Perception.EARSHOT or 10)
            * hearing * weather)
        return dx * dx + dy * dy <= reach * reach
    end
    if channel ~= nil then return false end
    local a, b = bodyFor(fromId), bodyFor(toId)
    if not a or not b then return false end
    local ok, heard = pcall(function()
        return SAOJavaBridge:canConverseNow(a, b,
            SAO.Perception and SAO.Perception.EARSHOT or 10)
    end)
    return ok and heard == true
end

function Communication.send(fromId, toId, kind, payload)
    if type(fromId) ~= "string" or type(toId) ~= "string"
        or type(kind) ~= "string" then
        return nil
    end
    local message = {
        from = fromId,
        to = toId,
        kind = kind,
        payload = payload,
        at = SAO.History and SAO.History.countyHours() or 0,
        delivered = false,
    }
    Communication.messages[#Communication.messages + 1] = message
    return message
end

function Communication.deliver(message)
    if type(message) ~= "table" then return false end
    message.delivered = true
    if SAO.Organization and message.kind == "claim"
        and type(message.payload) == "table"
        and type(message.payload.kind) == "string" then
        SAO.Organization.recordClaim(
            message.from,
            message.payload.kind,
            message.payload.target,
            message.payload.organization
        )
    end
    -- [C105] Delivered is done: the fact now lives where it was
    -- recorded, and the carrier does not hoard spent messages -
    -- a county that talks for years must not grow a wire that
    -- never shortens.
    for i, m in ipairs(Communication.messages) do
        if m == message then
            table.remove(Communication.messages, i)
            break
        end
    end
    return true
end

function Communication.pendingFor(id)
    local pending = {}
    for _, message in ipairs(Communication.messages) do
        if message.to == id and not message.delivered then
            pending[#pending + 1] = message
        end
    end
    return pending
end

return Communication
