local function square(x, y, z)
    return { getX = function() return x end,
        getY = function() return y end,
        getZ = function() return z end }
end
__square = square
__clock = 100
__heard = true
__dropAfterFirst = false
__canCalls = 0
__objectiveLearning = {}
__failAfterCanCalls = nil
__playerSlot = 0
__duplicatePlayer, __duplicateSlot = nil, nil
__player = { x = 0, y = 0, z = 0 }
function __player:getX() return self.x end
function __player:getY() return self.y end
function __player:getZ() return self.z end
function __player:getCurrentSquare() return square(self.x, self.y, self.z) end
function __player:getUsername() return "operator" end
function __player:isDead() return false end
__person = { id = "helper", x = 1, y = 0, z = 0, dead = false,
    hunger = 0, bodyOwner = nil }
__body = { x = 1, y = 0, z = 0 }
function __body:getX() return self.x end
function __body:getY() return self.y end
function __body:getZ() return self.z end
function __body:getCurrentSquare() return square(self.x, self.y, self.z) end
function __body:isDead() return false end
getSpecificPlayer = function(index)
    if index == __duplicateSlot then return __duplicatePlayer end
    return index == __playerSlot and __player or nil
end
HaloTextHelper = { addText = function(_, message) __lastText = message end }
Events = setmetatable({}, { __index = function(t, key)
    local slot = { Add = function() end, Remove = function() end }
    rawset(t, key, slot)
    return slot
end })
SAOJavaBridge = { canConverseNow = function(_, a, b)
    if __dropAfterFirst or __failAfterCanCalls then
        __canCalls = __canCalls + 1
        if __dropAfterFirst and __canCalls > 1 then return false end
        if __failAfterCanCalls and __canCalls > __failAfterCanCalls then
            return false
        end
    end
    if not __heard or not a or not b then return false end
    local dx, dy = a:getX() - b:getX(), a:getY() - b:getY()
    return a:getZ() == b:getZ() and dx * dx + dy * dy <= 25
end }
SAO = {
    Participants = { player = function(index)
        local player = getSpecificPlayer(index)
        return player and not player.observer and player or nil
    end },
    Log = { line = function() end },
    History = { countyHours = function() return __clock end },
    Identity = { get = function(id)
        return id == "helper" and __person or nil
    end },
    Body = { active = { helper = __body }, foreign = {},
        get = function(id)
            return id == "helper" and SAO.Body.active.helper or nil
        end },
    Controller = { agents = { helper = { rec = __person, state = "IDLE" } } },
    Standing = {
        playerKey = function(player)
            return player and player.getUsername
                and player:getUsername() == "operator"
                and "player:operator" or nil
        end,
        groupOf = function() return nil end,
        trust = function() return 0.5 end,
        isHostileTo = function() return false end,
    },
    Needs = { read = function() return { hunger = 0, thirst = 0 } end },
    Perception = { EARSHOT = 10 },
    Cognition = { commitmentOutcome = function(id, row)
        __objectiveLearning[#__objectiveLearning + 1] = {
            actorId = id, sequence = row.sequence, kind = row.workKind,
            receiptId = row.nativeReceiptId }
        return true
    end },
}
