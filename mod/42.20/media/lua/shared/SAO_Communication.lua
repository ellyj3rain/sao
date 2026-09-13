-- SAO_Communication.lua - claims that pass between people.

SAO = SAO or {}
SAO.Communication = SAO.Communication or {}
local Communication = SAO.Communication

Communication.messages = Communication.messages or {}

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
        at = 0,
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
